import Foundation

nonisolated protocol PlaybackRestoring: Sendable {
    func load() async throws -> PlaybackRestorationSnapshot?
    func save(_ snapshot: PlaybackRestorationSnapshot) async throws
    func clear() async throws
}

actor PlaybackRestorationCoordinator {
    private let store: any PlaybackRestoring
    private var latestSequence = 0

    init(store: any PlaybackRestoring) {
        self.store = store
    }

    func load() async throws -> PlaybackRestorationSnapshot? {
        try await store.load()
    }

    func write(
        _ snapshot: PlaybackRestorationSnapshot?,
        sequence: Int
    ) async throws {
        guard sequence > latestSequence else {
            return
        }
        latestSequence = sequence
        if let snapshot {
            try await store.save(snapshot)
        } else {
            try await store.clear()
        }
    }
}
