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

    private let repository: any LibraryRepository
    private let prepareForInitialLoad: @Sendable () async throws -> Void
    private var hasPreparedInitialLoad = false

    init(
        repository: any LibraryRepository,
        initialState: LibraryLoadState = .idle,
        prepareForInitialLoad: @escaping @Sendable () async throws -> Void = {}
    ) {
        self.repository = repository
        state = initialState
        self.prepareForInitialLoad = prepareForInitialLoad
    }

    func load() async {
        guard state != .loading else {
            return
        }

        let previousState = state
        state = .loading
        do {
            if !hasPreparedInitialLoad {
                try await prepareForInitialLoad()
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
}
