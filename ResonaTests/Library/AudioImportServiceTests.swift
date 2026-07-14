import Foundation
import Testing
@testable import Resona

@MainActor
struct AudioImportServiceTests {
    @Test func realAACFixtureImportsThroughProductionAdapters() async throws {
        let context = try makeContext()
        defer { context.cleanup() }
        let sourceURL = try AudioFixture.url("supported-aac", extension: "m4a")
        let songID = UUID()
        let service = AudioImportService(
            repository: context.repository,
            mediaStore: context.mediaStore,
            sourceAccessor: DirectImportSourceAccessor(),
            validator: AVFoundationAudioValidator(),
            metadataReader: AVFoundationAudioMetadataReader(),
            makeUUID: { songID }
        )

        let events = await collect(
            try await service.importFiles(at: [sourceURL])
        )

        #expect(results(in: events).map(\.outcome) == [.imported(songID)])
        let songs = try await context.repository.fetchSongs(
            locale: Locale(identifier: "en_US")
        )
        #expect(songs.count == 1)
        let song = try #require(songs.first)
        #expect(song.title == "Fixture Title")
        #expect(song.artist == "Fixture Artist")
        #expect(song.album == "Fixture Album")
        #expect(try #require(song.durationSeconds) > 0)
        if case .available = song.availability {
            #expect(true)
        } else {
            Issue.record("Expected imported fixture to be available")
        }
    }

    @Test func sequentialImportMakesSameOperationDuplicateVisible() async throws {
        let context = try makeContext()
        defer { context.cleanup() }
        let firstURL = try sourceFile(
            named: "first.mp3",
            data: Data("identical audio bytes".utf8),
            in: context.temporaryURL
        )
        let secondURL = try sourceFile(
            named: "second.mp3",
            data: Data("identical audio bytes".utf8),
            in: context.temporaryURL
        )
        let songID = UUID()
        let validator = SequenceAudioValidator(
            results: [successfulValidation, successfulValidation]
        )
        let service = AudioImportService(
            repository: context.repository,
            mediaStore: context.mediaStore,
            sourceAccessor: DirectImportSourceAccessor(),
            validator: validator,
            metadataReader: StubAudioMetadataReader(),
            makeUUID: { songID }
        )

        let events = await collect(
            try await service.importFiles(at: [firstURL, secondURL])
        )

        #expect(
            results(in: events).map(\.outcome) == [
                .imported(songID),
                .alreadyImported(songID),
            ]
        )
        let songs = try await context.repository.fetchSongs(
            locale: Locale(identifier: "en_US")
        )
        #expect(songs.count == 1)
        #expect(songs[0].id == songID)
    }

    @Test func sameFilenameAndMetadataWithDifferentBytesRemainDistinct() async throws {
        let context = try makeContext()
        defer { context.cleanup() }
        let firstDirectory = context.temporaryURL.appending(
            path: "First",
            directoryHint: .isDirectory
        )
        let secondDirectory = context.temporaryURL.appending(
            path: "Second",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: firstDirectory,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: secondDirectory,
            withIntermediateDirectories: true
        )
        let firstURL = try sourceFile(
            named: "Same Name.mp3",
            data: Data("first unique bytes".utf8),
            in: firstDirectory
        )
        let secondURL = try sourceFile(
            named: "Same Name.mp3",
            data: Data("second unique bytes".utf8),
            in: secondDirectory
        )
        let firstSongID = testUUID(3)
        let secondSongID = testUUID(5)
        let uuidSequence = LockedUUIDSequence()
        let service = AudioImportService(
            repository: context.repository,
            mediaStore: context.mediaStore,
            sourceAccessor: DirectImportSourceAccessor(),
            validator: SequenceAudioValidator(
                results: [successfulValidation, successfulValidation]
            ),
            metadataReader: StubAudioMetadataReader(
                metadata: RawAudioMetadata(title: "Same Metadata")
            ),
            makeUUID: { uuidSequence.next() }
        )

        let events = await collect(
            try await service.importFiles(at: [firstURL, secondURL])
        )

        #expect(
            results(in: events).map(\.outcome) == [
                .imported(firstSongID),
                .imported(secondSongID),
            ]
        )
        let songs = try await context.repository.fetchSongs(
            locale: Locale(identifier: "en_US")
        )
        #expect(Set(songs.map(\.id)) == [firstSongID, secondSongID])
        #expect(songs.map(\.title) == ["Same Metadata", "Same Metadata"])
    }

    @Test func matchingUnavailableSongIsRestoredWithoutChangingIdentity() async throws {
        let context = try makeContext()
        defer { context.cleanup() }
        let bytes = Data("restorable audio bytes".utf8)
        let sourceURL = try sourceFile(
            named: "restored.mp3",
            data: bytes,
            in: context.temporaryURL
        )
        let fingerprintCopyURL = context.temporaryURL.appending(
            path: "fingerprint-copy"
        )
        let fingerprint = try SHA256ContentFingerprinter().copyAndFingerprint(
            from: sourceURL,
            to: fingerprintCopyURL
        )
        let existingID = UUID()
        try await context.repository.insert(
            LibrarySongDraft(
                id: existingID,
                fingerprint: fingerprint,
                managedAudioFilename: "missing.mp3",
                title: "Old Title",
                artist: nil,
                album: nil,
                durationSeconds: nil,
                managedArtworkFilename: nil
            )
        )
        let generatedID = UUID()
        let service = AudioImportService(
            repository: context.repository,
            mediaStore: context.mediaStore,
            sourceAccessor: DirectImportSourceAccessor(),
            validator: SequenceAudioValidator(results: [successfulValidation]),
            metadataReader: StubAudioMetadataReader(
                metadata: RawAudioMetadata(title: "Restored Title")
            ),
            makeUUID: { generatedID }
        )

        let events = await collect(
            try await service.importFiles(at: [sourceURL])
        )

        #expect(results(in: events).map(\.outcome) == [.restored(existingID)])
        let songs = try await context.repository.fetchSongs(
            locale: Locale(identifier: "en_US")
        )
        #expect(songs.count == 1)
        #expect(songs[0].id == existingID)
        #expect(songs[0].title == "Restored Title")
        if case .available = songs[0].availability {
            #expect(true)
        } else {
            Issue.record("Expected restored audio to be available")
        }
    }

    @Test func mixedOperationKeepsSuccessAndReportsIndependentFailure() async throws {
        let context = try makeContext()
        defer { context.cleanup() }
        let validURL = try sourceFile(
            named: "valid.mp3",
            data: Data("valid bytes".utf8),
            in: context.temporaryURL
        )
        let invalidURL = try sourceFile(
            named: "invalid.flac",
            data: Data("invalid bytes".utf8),
            in: context.temporaryURL
        )
        let songID = UUID()
        let service = AudioImportService(
            repository: context.repository,
            mediaStore: context.mediaStore,
            sourceAccessor: DirectImportSourceAccessor(),
            validator: SequenceAudioValidator(
                results: [
                    successfulValidation,
                    .failure(.unsupportedContainer),
                ]
            ),
            metadataReader: StubAudioMetadataReader(),
            makeUUID: { songID }
        )

        let events = await collect(
            try await service.importFiles(at: [validURL, invalidURL])
        )

        #expect(
            results(in: events).map(\.outcome) == [
                .imported(songID),
                .failed(.unsupportedContainer),
            ]
        )
        #expect(
            progress(in: events).map(\.completedFileCount)
                == [0, 0, 1, 1, 2]
        )
        let songs = try await context.repository.fetchSongs(
            locale: Locale(identifier: "en_US")
        )
        #expect(songs.count == 1)
    }

    @Test func persistenceFailureRemovesCommittedManagedResources() async throws {
        let temporaryURL = FileManager.default.temporaryDirectory.appending(
            path: UUID().uuidString,
            directoryHint: .isDirectory
        )
        defer { try? FileManager.default.removeItem(at: temporaryURL) }
        try FileManager.default.createDirectory(
            at: temporaryURL,
            withIntermediateDirectories: true
        )
        let sourceURL = try sourceFile(
            named: "song.mp3",
            data: Data("audio bytes".utf8),
            in: temporaryURL
        )
        let mediaRootURL = temporaryURL.appending(
            path: "ManagedLibrary",
            directoryHint: .isDirectory
        )
        let mediaStore = ManagedMediaStore(rootURL: mediaRootURL)
        let service = AudioImportService(
            repository: FailingInsertLibraryRepository(),
            mediaStore: mediaStore,
            sourceAccessor: DirectImportSourceAccessor(),
            validator: SequenceAudioValidator(results: [successfulValidation]),
            metadataReader: StubAudioMetadataReader()
        )

        let events = await collect(
            try await service.importFiles(at: [sourceURL])
        )

        #expect(
            results(in: events).map(\.outcome)
                == [.failed(.persistenceFailed)]
        )
        let audioContents = try FileManager.default.contentsOfDirectory(
            at: mediaRootURL.appending(
                path: "Audio",
                directoryHint: .isDirectory
            ),
            includingPropertiesForKeys: nil
        )
        #expect(audioContents.isEmpty)
    }

    @Test func outOfSpaceDuringStagingUsesTypedStorageFailure() async throws {
        let context = try makeContext()
        defer { context.cleanup() }
        let sourceURL = try sourceFile(
            named: "song.mp3",
            data: Data("audio bytes".utf8),
            in: context.temporaryURL
        )
        let service = AudioImportService(
            repository: context.repository,
            mediaStore: context.mediaStore,
            sourceAccessor: OutOfSpaceImportSourceAccessor(),
            validator: SequenceAudioValidator(results: []),
            metadataReader: StubAudioMetadataReader()
        )

        let events = await collect(
            try await service.importFiles(at: [sourceURL])
        )

        #expect(
            results(in: events).map(\.outcome)
                == [.failed(.insufficientStorage)]
        )
    }

    @Test func unreadableMetadataUsesFilenameAndCommitsWithWarning() async throws {
        let context = try makeContext()
        defer { context.cleanup() }
        let sourceURL = try sourceFile(
            named: "Filename Fallback.mp3",
            data: Data("audio bytes".utf8),
            in: context.temporaryURL
        )
        let songID = UUID()
        let service = AudioImportService(
            repository: context.repository,
            mediaStore: context.mediaStore,
            sourceAccessor: DirectImportSourceAccessor(),
            validator: SequenceAudioValidator(results: [successfulValidation]),
            metadataReader: FailingAudioMetadataReader(),
            makeUUID: { songID }
        )

        let events = await collect(
            try await service.importFiles(at: [sourceURL])
        )

        #expect(
            results(in: events).map(\.outcome)
                == [.warning(songID, [.metadataUnreadable])]
        )
        let songs = try await context.repository.fetchSongs(
            locale: Locale(identifier: "en_US")
        )
        #expect(songs.map(\.title) == ["Filename Fallback"])
    }

    @Test func cancellationMarksCurrentAndPendingFilesWithoutCommitting() async throws {
        let context = try makeContext()
        defer { context.cleanup() }
        let firstURL = try sourceFile(
            named: "first.mp3",
            data: Data("first bytes".utf8),
            in: context.temporaryURL
        )
        let secondURL = try sourceFile(
            named: "second.mp3",
            data: Data("second bytes".utf8),
            in: context.temporaryURL
        )
        let validator = BlockingAudioValidator()
        let service = AudioImportService(
            repository: context.repository,
            mediaStore: context.mediaStore,
            sourceAccessor: DirectImportSourceAccessor(),
            validator: validator,
            metadataReader: StubAudioMetadataReader()
        )
        let stream = try await service.importFiles(at: [firstURL, secondURL])
        let collector = Task { await collect(stream) }
        while !(await validator.hasStarted) {
            await Task.yield()
        }

        do {
            _ = try await service.importFiles(at: [secondURL])
            Issue.record("Expected active import serialization")
        } catch let error as AudioImportServiceError {
            #expect(error == .operationInProgress)
        }

        await service.cancelActiveImport()
        let events = await collector.value

        #expect(
            results(in: events).map(\.outcome) == [.cancelled, .cancelled]
        )
        let songs = try await context.repository.fetchSongs(
            locale: Locale(identifier: "en_US")
        )
        #expect(songs.isEmpty)
    }

    @Test func retryStartsFreshWorkForOnlyTheRequestedFile() async throws {
        let context = try makeContext()
        defer { context.cleanup() }
        let sourceURL = try sourceFile(
            named: "retry.mp3",
            data: Data("retry bytes".utf8),
            in: context.temporaryURL
        )
        let songID = UUID()
        let validator = SequenceAudioValidator(
            results: [.failure(.corruptAudio), successfulValidation]
        )
        let service = AudioImportService(
            repository: context.repository,
            mediaStore: context.mediaStore,
            sourceAccessor: DirectImportSourceAccessor(),
            validator: validator,
            metadataReader: StubAudioMetadataReader(),
            makeUUID: { songID }
        )

        let firstEvents = await collect(
            try await service.importFiles(at: [sourceURL])
        )
        let retryEvents = await collect(
            try await service.retryFile(at: sourceURL)
        )

        #expect(
            results(in: firstEvents).map(\.outcome)
                == [.failed(.corruptAudio)]
        )
        #expect(results(in: retryEvents).map(\.outcome) == [.imported(songID)])
        #expect(await validator.callCount == 2)
    }

    private var successfulValidation: Result<ValidatedAudio, AudioValidationError> {
        .success(
            ValidatedAudio(
                canonicalFileExtension: "mp3",
                mimeType: "audio/mpeg",
                durationSeconds: 12
            )
        )
    }

    private func makeContext() throws -> ImportTestContext {
        let temporaryURL = FileManager.default.temporaryDirectory.appending(
            path: UUID().uuidString,
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: temporaryURL,
            withIntermediateDirectories: true
        )
        let mediaStore = ManagedMediaStore(
            rootURL: temporaryURL.appending(
                path: "ManagedLibrary",
                directoryHint: .isDirectory
            )
        )
        let container = try ResonaModelContainer.make(
            isStoredInMemoryOnly: true
        )
        let repository = SwiftDataLibraryRepository(
            modelContainer: container,
            resourceResolver: mediaStore
        )
        return ImportTestContext(
            temporaryURL: temporaryURL,
            mediaStore: mediaStore,
            repository: repository
        )
    }

    private func sourceFile(
        named name: String,
        data: Data,
        in directoryURL: URL
    ) throws -> URL {
        let url = directoryURL.appending(path: name)
        try data.write(to: url)
        return url
    }

    private func collect(_ stream: AsyncStream<ImportEvent>) async -> [ImportEvent] {
        var events: [ImportEvent] = []
        for await event in stream {
            events.append(event)
        }
        return events
    }

    private func results(in events: [ImportEvent]) -> [ImportFileResult] {
        events.compactMap { event in
            guard case let .result(result) = event else {
                return nil
            }
            return result
        }
    }

    private func progress(in events: [ImportEvent]) -> [ImportProgress] {
        events.compactMap { event in
            guard case let .progress(progress) = event else {
                return nil
            }
            return progress
        }
    }
}

private struct ImportTestContext {
    let temporaryURL: URL
    let mediaStore: ManagedMediaStore
    let repository: SwiftDataLibraryRepository

    func cleanup() {
        try? FileManager.default.removeItem(at: temporaryURL)
    }
}

private struct DirectImportSourceAccessor: ImportSourceAccessing {
    func copyToStaging(
        from sourceURL: URL,
        to stagingURL: URL,
        fingerprinter: any ContentFingerprinting
    ) async throws -> ContentFingerprint {
        try fingerprinter.copyAndFingerprint(
            from: sourceURL,
            to: stagingURL
        )
    }
}

private struct OutOfSpaceImportSourceAccessor: ImportSourceAccessing {
    func copyToStaging(
        from sourceURL: URL,
        to stagingURL: URL,
        fingerprinter: any ContentFingerprinting
    ) async throws -> ContentFingerprint {
        throw CocoaError(.fileWriteOutOfSpace)
    }
}

private actor SequenceAudioValidator: AudioValidating {
    private var results: [Result<ValidatedAudio, AudioValidationError>]
    private(set) var callCount = 0

    init(results: [Result<ValidatedAudio, AudioValidationError>]) {
        self.results = results
    }

    func validateAudio(at url: URL) async throws -> ValidatedAudio {
        callCount += 1
        guard !results.isEmpty else {
            throw AudioValidationError.corruptAudio
        }
        return try results.removeFirst().get()
    }
}

private actor BlockingAudioValidator: AudioValidating {
    private(set) var hasStarted = false

    func validateAudio(at url: URL) async throws -> ValidatedAudio {
        hasStarted = true
        while true {
            try Task.checkCancellation()
            await Task.yield()
        }
    }
}

private struct StubAudioMetadataReader: AudioMetadataReading {
    let metadata: RawAudioMetadata

    init(metadata: RawAudioMetadata = RawAudioMetadata(title: "Song")) {
        self.metadata = metadata
    }

    func readMetadata(
        at url: URL,
        mimeType: String
    ) async throws -> RawAudioMetadata {
        metadata
    }
}

private struct FailingAudioMetadataReader: AudioMetadataReading {
    func readMetadata(
        at url: URL,
        mimeType: String
    ) async throws -> RawAudioMetadata {
        throw CocoaError(.fileReadCorruptFile)
    }
}

private actor FailingInsertLibraryRepository: LibraryRepository {
    func fetchSongs(locale: Locale) async throws -> [LibrarySong] {
        []
    }

    func resourceReferences() async throws -> LibraryResourceReferences {
        LibraryResourceReferences()
    }

    func duplicateCandidates(
        matching fingerprint: ContentFingerprint
    ) async throws -> [LibraryDuplicateCandidate] {
        []
    }

    func insert(_ draft: LibrarySongDraft) async throws {
        throw TestRepositoryError.insertFailed
    }

    func restore(_ draft: LibrarySongDraft) async throws {
        throw TestRepositoryError.insertFailed
    }

    func beginRemoval(id: UUID) -> LibraryRemovalBeginning { .missing }

    func pendingRemovals() -> [LibrarySongRemoval] { [] }

    func finalizeRemoval(id: UUID) {}
}

private enum TestRepositoryError: Error {
    case insertFailed
}

// NSLock serializes every access to `values`, making this synchronous test
// generator safe to capture in the service's @Sendable UUID closure.
private final class LockedUUIDSequence: @unchecked Sendable {
    private let lock = NSLock()
    private var nextValue: UInt8 = 1

    func next() -> UUID {
        lock.lock()
        defer { lock.unlock() }
        let uuid = testUUID(nextValue)
        nextValue += 1
        return uuid
    }
}

nonisolated private func testUUID(_ value: UInt8) -> UUID {
    UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value))
}
