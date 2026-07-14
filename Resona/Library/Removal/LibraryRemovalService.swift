import Foundation

actor LibraryRemovalService: LibraryRemovalReconciling {
    private let repository: any LibraryRepository
    private let mediaStore: any ManagedMediaStoring
    private let mutationGate: LibraryMutationGate

    init(
        repository: any LibraryRepository,
        mediaStore: any ManagedMediaStoring,
        mutationGate: LibraryMutationGate
    ) {
        self.repository = repository
        self.mediaStore = mediaStore
        self.mutationGate = mutationGate
    }

    func remove(
        id: UUID,
        beforeRemoval: @Sendable () async throws -> Void = {},
        afterAcceptance: @Sendable () async -> Void = {}
    ) async -> LibraryRemovalOutcome {
        guard case let .acquired(reservation) = await mutationGate.acquire() else {
            return .busy
        }

        let outcome = await performRemoval(
            id: id,
            reservation: reservation,
            beforeRemoval: beforeRemoval,
            afterAcceptance: afterAcceptance
        )
        await mutationGate.release(reservation)
        return outcome
    }

    func retryRemoval(id: UUID) async -> LibraryRemovalRetryOutcome {
        guard case let .acquired(reservation) = await mutationGate.acquire() else {
            return .busy
        }

        let outcome = await performRetry(id: id, reservation: reservation)
        await mutationGate.release(reservation)
        return outcome
    }

    func reconcileLibrary() async throws -> [LibraryRemovalIssue] {
        guard case let .acquired(reservation) = await mutationGate.acquire() else {
            throw LibraryRemovalServiceError.operationInProgress
        }

        do {
            let issues = try await reconcile(using: reservation)
            await mutationGate.release(reservation)
            return issues
        } catch {
            await mutationGate.release(reservation)
            throw error
        }
    }

    func reconcile(
        using reservation: LibraryMutationReservation
    ) async throws -> [LibraryRemovalIssue] {
        guard await mutationGate.isHeld(reservation) else {
            throw LibraryRemovalServiceError.invalidReservation
        }

        let pendingRemovals: [LibrarySongRemoval]
        do {
            pendingRemovals = try await repository.pendingRemovals()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw LibraryRemovalReconciliationError.persistenceFailed
        }
        var issues: [LibraryRemovalIssue] = []
        issues.reserveCapacity(pendingRemovals.count)

        for removal in pendingRemovals {
            if let issue = await cleanup(removal) {
                issues.append(issue)
            }
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
        return issues
    }

    private func performRemoval(
        id: UUID,
        reservation: LibraryMutationReservation,
        beforeRemoval: @Sendable () async throws -> Void,
        afterAcceptance: @Sendable () async -> Void
    ) async -> LibraryRemovalOutcome {
        do {
            _ = try await reconcile(using: reservation)
            try Task.checkCancellation()
            try await beforeRemoval()
            try Task.checkCancellation()
        } catch {
            return .notAccepted
        }

        let beginning: LibraryRemovalBeginning
        do {
            beginning = try await repository.beginRemoval(id: id)
        } catch {
            return .notAccepted
        }

        switch beginning {
        case .missing:
            return .missing
        case let .accepted(removal):
            await afterAcceptance()
            if let issue = await cleanup(removal) {
                return .pendingCleanup(issue)
            }
            return .removed
        }
    }

    private func performRetry(
        id: UUID,
        reservation: LibraryMutationReservation
    ) async -> LibraryRemovalRetryOutcome {
        guard await mutationGate.isHeld(reservation) else {
            return .failed
        }

        let removals: [LibrarySongRemoval]
        do {
            removals = try await repository.pendingRemovals()
        } catch {
            return .failed
        }

        guard let removal = removals.first(where: { $0.id == id }) else {
            return .missing
        }
        if let issue = await cleanup(removal) {
            return .pendingCleanup(issue)
        }

        do {
            let references = try await repository.resourceReferences()
            try await mediaStore.reconcile(references: references)
            return .completed
        } catch {
            return .failed
        }
    }

    private func cleanup(
        _ removal: LibrarySongRemoval
    ) async -> LibraryRemovalIssue? {
        let issue = LibraryRemovalIssue(id: removal.id, title: removal.title)
        do {
            try await mediaStore.removeResources(
                audioFilename: removal.managedAudioFilename,
                artworkFilename: removal.managedArtworkFilename
            )
            try await repository.finalizeRemoval(id: removal.id)
            return nil
        } catch {
            return issue
        }
    }
}

nonisolated enum LibraryRemovalServiceError: Error, Equatable {
    case operationInProgress
    case invalidReservation
}
