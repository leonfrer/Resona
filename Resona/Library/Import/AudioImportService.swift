import Foundation

actor AudioImportService {
    private let repository: any LibraryRepository
    private let mediaStore: any ManagedMediaStoring
    private let sourceAccessor: any ImportSourceAccessing
    private let fingerprinter: any ContentFingerprinting
    private let validator: any AudioValidating
    private let metadataReader: any AudioMetadataReading
    private let metadataNormalizer: AudioMetadataNormalizer
    private let mutationGate: LibraryMutationGate
    private let removalReconciler: (any LibraryRemovalReconciling)?
    private let makeUUID: @Sendable () -> UUID

    private var activeTask: Task<Void, Never>?

    init(
        repository: any LibraryRepository,
        mediaStore: any ManagedMediaStoring,
        sourceAccessor: any ImportSourceAccessing =
            SecurityScopedImportSourceAccessor(),
        fingerprinter: any ContentFingerprinting =
            SHA256ContentFingerprinter(),
        validator: any AudioValidating = AVFoundationAudioValidator(),
        metadataReader: any AudioMetadataReading =
            AVFoundationAudioMetadataReader(),
        metadataNormalizer: AudioMetadataNormalizer = AudioMetadataNormalizer(),
        mutationGate: LibraryMutationGate = LibraryMutationGate(),
        removalReconciler: (any LibraryRemovalReconciling)? = nil,
        makeUUID: @escaping @Sendable () -> UUID = UUID.init
    ) {
        self.repository = repository
        self.mediaStore = mediaStore
        self.sourceAccessor = sourceAccessor
        self.fingerprinter = fingerprinter
        self.validator = validator
        self.metadataReader = metadataReader
        self.metadataNormalizer = metadataNormalizer
        self.mutationGate = mutationGate
        self.removalReconciler = removalReconciler
        self.makeUUID = makeUUID
    }

    func importFiles(
        at sourceURLs: [URL]
    ) async throws -> AsyncStream<ImportEvent> {
        guard activeTask == nil else {
            throw AudioImportServiceError.operationInProgress
        }
        guard case let .acquired(reservation) = await mutationGate.acquire() else {
            throw AudioImportServiceError.operationInProgress
        }

        let (stream, continuation) = AsyncStream<ImportEvent>.makeStream()
        let operationID = makeUUID()
        let task = Task {
            await runImport(
                sourceURLs: sourceURLs,
                operationID: operationID,
                reservation: reservation,
                continuation: continuation
            )
        }
        activeTask = task
        continuation.onTermination = { @Sendable _ in
            task.cancel()
        }
        return stream
    }

    func retryFile(at sourceURL: URL) async throws -> AsyncStream<ImportEvent> {
        try await importFiles(at: [sourceURL])
    }

    func cancelActiveImport() async {
        activeTask?.cancel()
    }

    func reconcileLibrary() async throws {
        guard case let .acquired(reservation) = await mutationGate.acquire() else {
            throw AudioImportServiceError.operationInProgress
        }

        do {
            try await reconcile(using: reservation)
            await mutationGate.release(reservation)
        } catch {
            await mutationGate.release(reservation)
            throw error
        }
    }

    private func runImport(
        sourceURLs: [URL],
        operationID: UUID,
        reservation: LibraryMutationReservation,
        continuation: AsyncStream<ImportEvent>.Continuation
    ) async {
        let totalCount = sourceURLs.count
        continuation.yield(
            .progress(
                ImportProgress(
                    completedFileCount: 0,
                    totalFileCount: totalCount,
                    currentSourceDisplayName: nil
                )
            )
        )

        let reconciliationFailure = await reconcileBeforeImport(
            using: reservation
        )
        var completedCount = 0
        for sourceURL in sourceURLs {
            let displayName = sourceDisplayName(for: sourceURL)
            continuation.yield(
                .progress(
                    ImportProgress(
                        completedFileCount: completedCount,
                        totalFileCount: totalCount,
                        currentSourceDisplayName: displayName
                    )
                )
            )

            let result: ImportFileResult
            if Task.isCancelled {
                result = ImportFileResult(
                    sourceDisplayName: displayName,
                    outcome: .cancelled
                )
            } else if let reconciliationFailure {
                result = ImportFileResult(
                    sourceDisplayName: displayName,
                    outcome: .failed(reconciliationFailure)
                )
            } else {
                result = await importFile(
                    at: sourceURL,
                    displayName: displayName,
                    operationID: operationID
                )
            }

            completedCount += 1
            continuation.yield(.result(result))
            continuation.yield(
                .progress(
                    ImportProgress(
                        completedFileCount: completedCount,
                        totalFileCount: totalCount,
                        currentSourceDisplayName: nil
                    )
                )
            )
        }

        try? await mediaStore.removeStagingOperation(id: operationID)
        continuation.yield(.finished)
        continuation.finish()
        activeTask = nil
        await mutationGate.release(reservation)
    }

    private func reconcileBeforeImport(
        using reservation: LibraryMutationReservation
    ) async -> ImportFailureReason? {
        do {
            try await reconcile(using: reservation)
            return nil
        } catch is CancellationError {
            return nil
        } catch let error as LibraryRemovalReconciliationError {
            switch error {
            case .persistenceFailed:
                return .persistenceFailed
            case .managedStorageFailed:
                return .managedStorageFailed
            }
        } catch {
            return .managedStorageFailed
        }
    }

    private func reconcile(
        using reservation: LibraryMutationReservation
    ) async throws {
        if let removalReconciler {
            _ = try await removalReconciler.reconcile(using: reservation)
            return
        }

        let references: LibraryResourceReferences
        do {
            references = try await repository.resourceReferences()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw LibraryRemovalReconciliationError.persistenceFailed
        }
        do {
            try await mediaStore.reconcile(references: references)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw LibraryRemovalReconciliationError.managedStorageFailed
        }
    }

    private func importFile(
        at sourceURL: URL,
        displayName: String,
        operationID: UUID
    ) async -> ImportFileResult {
        do {
            let candidateID = makeUUID()
            let stagingURL = try await mediaStore.stagingURL(
                operationID: operationID,
                candidateID: candidateID
            )
            let fingerprint: ContentFingerprint
            do {
                fingerprint = try await sourceAccessor.copyToStaging(
                    from: sourceURL,
                    to: stagingURL,
                    fingerprinter: fingerprinter
                )
            } catch {
                throw ImportCoordinationError.source(error)
            }

            let validatedAudio = try await validator.validateAudio(at: stagingURL)
            let candidates: [LibraryDuplicateCandidate]
            do {
                candidates = try await repository.duplicateCandidates(
                    matching: fingerprint
                )
            } catch {
                throw ImportCoordinationError.persistence(error)
            }
            for candidate in candidates where candidate.managedAudioURL != nil {
                let matches: Bool
                do {
                    matches = try await mediaStore.contentsEqual(
                        stagedURL: stagingURL,
                        managedAudioFilename: candidate.managedAudioFilename
                    )
                } catch {
                    throw ImportCoordinationError.storage(error)
                }
                if matches {
                    try? await mediaStore.removeStagingOperation(id: operationID)
                    return ImportFileResult(
                        sourceDisplayName: displayName,
                        outcome: .alreadyImported(candidate.id)
                    )
                }
            }

            let unavailableCandidate = candidates.first {
                $0.managedAudioURL == nil
            }
            let songID = unavailableCandidate?.id ?? makeUUID()
            let normalizedMetadata = try await readAndNormalizeMetadata(
                at: stagingURL,
                displayName: displayName,
                mimeType: validatedAudio.mimeType
            )
            var warnings = normalizedMetadata.warnings

            let audioFilename: String
            do {
                audioFilename = try await mediaStore.commitAudio(
                    from: stagingURL,
                    songID: songID,
                    fileExtension: validatedAudio.canonicalFileExtension
                )
            } catch {
                throw ImportCoordinationError.storage(error)
            }

            let artworkFilename = await commitArtworkIfPossible(
                normalizedMetadata.artwork,
                songID: songID,
                operationID: operationID,
                warnings: &warnings
            )
            let draft = LibrarySongDraft(
                id: songID,
                fingerprint: fingerprint,
                managedAudioFilename: audioFilename,
                title: normalizedMetadata.title,
                artist: normalizedMetadata.artist,
                album: normalizedMetadata.album,
                durationSeconds: validatedAudio.durationSeconds,
                managedArtworkFilename: artworkFilename
            )

            do {
                if unavailableCandidate == nil {
                    try await repository.insert(draft)
                } else {
                    try await repository.restore(draft)
                }
            } catch {
                try? await mediaStore.removeResources(
                    audioFilename: audioFilename,
                    artworkFilename: artworkFilename
                )
                throw ImportCoordinationError.persistence(error)
            }

            try? await mediaStore.removeStagingOperation(id: operationID)
            let outcome: ImportFileResult.Outcome
            if warnings.isEmpty {
                outcome = unavailableCandidate == nil
                    ? .imported(songID)
                    : .restored(songID)
            } else {
                outcome = .warning(songID, warnings)
            }
            return ImportFileResult(
                sourceDisplayName: displayName,
                outcome: outcome
            )
        } catch {
            try? await mediaStore.removeStagingOperation(id: operationID)
            return ImportFileResult(
                sourceDisplayName: displayName,
                outcome: failureOutcome(for: error)
            )
        }
    }

    private func readAndNormalizeMetadata(
        at stagingURL: URL,
        displayName: String,
        mimeType: String
    ) async throws -> NormalizedAudioMetadata {
        do {
            let metadata = try await metadataReader.readMetadata(
                at: stagingURL,
                mimeType: mimeType
            )
            return metadataNormalizer.normalize(
                metadata,
                sourceDisplayName: displayName
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if Task.isCancelled {
                throw CancellationError()
            }
            let normalized = metadataNormalizer.normalize(
                RawAudioMetadata(),
                sourceDisplayName: displayName
            )
            return NormalizedAudioMetadata(
                title: normalized.title,
                artist: normalized.artist,
                album: normalized.album,
                artwork: normalized.artwork,
                warnings: [.metadataUnreadable]
            )
        }
    }

    private func commitArtworkIfPossible(
        _ artwork: ValidatedArtwork?,
        songID: UUID,
        operationID: UUID,
        warnings: inout [ImportWarning]
    ) async -> String? {
        guard let artwork else {
            return nil
        }
        do {
            let artworkStagingURL = try await mediaStore.stagingURL(
                operationID: operationID,
                candidateID: makeUUID()
            )
            try artwork.data.write(to: artworkStagingURL)
            return try await mediaStore.commitArtwork(
                from: artworkStagingURL,
                songID: songID,
                fileExtension: artwork.canonicalFileExtension
            )
        } catch {
            warnings.append(.artworkStorageFailed)
            return nil
        }
    }

    private func failureOutcome(for error: Error) -> ImportFileResult.Outcome {
        if error is CancellationError || Task.isCancelled {
            return .cancelled
        }
        if let validationError = error as? AudioValidationError {
            switch validationError {
            case .unsupportedContainer: return .failed(.unsupportedContainer)
            case .unsupportedCodec: return .failed(.unsupportedCodec)
            case .protectedMedia: return .failed(.protectedMedia)
            case .videoOnly: return .failed(.videoOnly)
            case .corruptAudio: return .failed(.corruptAudio)
            }
        }
        if let coordinationError = error as? ImportCoordinationError {
            switch coordinationError {
            case let .source(underlyingError):
                return .failed(
                    isOutOfSpace(underlyingError)
                        ? .insufficientStorage
                        : .sourceAccessLost
                )
            case let .storage(underlyingError):
                return .failed(
                    isOutOfSpace(underlyingError)
                        ? .insufficientStorage
                        : .managedStorageFailed
                )
            case .persistence:
                return .failed(.persistenceFailed)
            }
        }
        return .failed(.managedStorageFailed)
    }

    private func isOutOfSpace(_ error: Error) -> Bool {
        let cocoaError = error as? CocoaError
        return cocoaError?.code == .fileWriteOutOfSpace
    }

    private func sourceDisplayName(for url: URL) -> String {
        let name = url.lastPathComponent
        return name.isEmpty ? "Selected File" : name
    }
}

nonisolated enum AudioImportServiceError: Error, Equatable {
    case operationInProgress
}

private enum ImportCoordinationError: Error {
    case source(Error)
    case storage(Error)
    case persistence(Error)
}
