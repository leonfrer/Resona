import Foundation
import Observation

nonisolated enum LibraryLoadState: Equatable, Sendable {
    case idle
    case loading
    case loaded([LibrarySong])
    case failed
}

@MainActor
@Observable
final class LibraryStore {
    private(set) var state: LibraryLoadState
    private(set) var removalInProgressIDs: Set<UUID>
    private(set) var removalRequestFailure: LibraryRemovalRequestFailure?
    private(set) var removalIssues: [LibraryRemovalIssue]

    private let repository: any LibraryRepository
    private let prepareForInitialLoad:
        @Sendable () async throws -> [LibraryRemovalIssue]
    private var hasPreparedInitialLoad = false

    init(
        repository: any LibraryRepository,
        initialState: LibraryLoadState = .idle,
        initialRemovalInProgressIDs: Set<UUID> = [],
        initialRemovalIssues: [LibraryRemovalIssue] = [],
        prepareForInitialLoad: @escaping @Sendable () async throws
            -> [LibraryRemovalIssue] = { [] }
    ) {
        self.repository = repository
        state = initialState
        removalInProgressIDs = initialRemovalInProgressIDs
        removalRequestFailure = nil
        removalIssues = Self.sortedUniqueIssues(initialRemovalIssues)
        self.prepareForInitialLoad = prepareForInitialLoad
    }

    var removalFeedback: LibraryRemovalFeedback? {
        if let removalRequestFailure {
            return .requestFailure(removalRequestFailure)
        }
        return removalIssues.first.map(LibraryRemovalFeedback.cleanupIssue)
    }

    func load() async {
        guard state != .loading else {
            return
        }

        let previousState = state
        state = .loading
        do {
            if !hasPreparedInitialLoad {
                mergeRemovalIssues(try await prepareForInitialLoad())
                hasPreparedInitialLoad = true
            }
            state = .loaded(
                try await repository.fetchSongs(locale: .autoupdatingCurrent)
            )
        } catch is CancellationError {
            state = previousState
        } catch {
            state = .failed
        }
    }

    func refresh() async {
        do {
            state = .loaded(
                try await repository.fetchSongs(locale: .autoupdatingCurrent)
            )
        } catch is CancellationError {
            return
        } catch {
            state = .failed
        }
    }

    func remove(
        _ song: LibrarySong,
        using remover: any LibraryRemoving,
        playbackInvalidator: any PlaybackRemovalInvalidating
    ) async {
        guard !removalInProgressIDs.contains(song.id) else {
            return
        }

        removalInProgressIDs.insert(song.id)
        removalRequestFailure = nil
        defer {
            removalInProgressIDs.remove(song.id)
        }

        let outcome = await remover.remove(
            id: song.id,
            beforeRemoval: {
                try await playbackInvalidator.beginRemovalInvalidation(
                    for: song.id
                )
            },
            afterAcceptance: {
                await playbackInvalidator.endRemovalInvalidation(for: song.id)
                await self.refresh()
            }
        )

        switch outcome {
        case .removed:
            break
        case let .pendingCleanup(issue):
            mergeRemovalIssues([issue])
        case .missing:
            playbackInvalidator.endRemovalInvalidation(for: song.id)
            await refresh()
        case .busy:
            removalRequestFailure = LibraryRemovalRequestFailure(
                song: song,
                reason: .busy
            )
        case .notAccepted:
            playbackInvalidator.endRemovalInvalidation(for: song.id)
            removalRequestFailure = LibraryRemovalRequestFailure(
                song: song,
                reason: .notAccepted
            )
            await refresh()
        }
    }

    func retryRemovalFeedback(
        _ feedback: LibraryRemovalFeedback,
        using remover: any LibraryRemoving,
        playbackInvalidator: any PlaybackRemovalInvalidating
    ) async {
        dismissRemovalFeedback(feedback)
        switch feedback {
        case let .requestFailure(failure):
            await remove(
                failure.song,
                using: remover,
                playbackInvalidator: playbackInvalidator
            )
        case let .cleanupIssue(issue):
            await retryCleanup(issue, using: remover)
        }
    }

    func dismissRemovalFeedback(_ feedback: LibraryRemovalFeedback) {
        switch feedback {
        case let .requestFailure(failure):
            guard removalRequestFailure == failure else {
                return
            }
            removalRequestFailure = nil
        case let .cleanupIssue(issue):
            removalIssues.removeAll { $0.id == issue.id }
        }
    }

    private func retryCleanup(
        _ issue: LibraryRemovalIssue,
        using remover: any LibraryRemoving
    ) async {
        guard !removalInProgressIDs.contains(issue.id) else {
            return
        }
        removalInProgressIDs.insert(issue.id)
        defer {
            removalInProgressIDs.remove(issue.id)
        }

        switch await remover.retryRemoval(id: issue.id) {
        case .completed, .missing:
            await refresh()
        case let .pendingCleanup(updatedIssue):
            mergeRemovalIssues([updatedIssue])
            await refresh()
        case .busy, .failed:
            mergeRemovalIssues([issue])
        }
    }

    private func mergeRemovalIssues(_ issues: [LibraryRemovalIssue]) {
        removalIssues = Self.sortedUniqueIssues(removalIssues + issues)
    }

    nonisolated private static func sortedUniqueIssues(
        _ issues: [LibraryRemovalIssue]
    ) -> [LibraryRemovalIssue] {
        var issuesByID: [UUID: LibraryRemovalIssue] = [:]
        for issue in issues {
            issuesByID[issue.id] = issue
        }
        return issuesByID.values.sorted {
            $0.id.uuidString < $1.id.uuidString
        }
    }
}
