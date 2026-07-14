import Foundation

nonisolated struct PlaybackRestorationSnapshot: Codable, Equatable, Sendable {
    static let currentVersion = 1

    let version: Int
    let baseOrder: [UUID]
    let currentID: UUID
    let position: TimeInterval
    let repeatMode: PlaybackRepeatMode
    let isShuffleEnabled: Bool
    let traversalOrder: [UUID]
    let history: [UUID]
    let historyIndex: Int?

    init(
        version: Int = currentVersion,
        baseOrder: [UUID],
        currentID: UUID,
        position: TimeInterval,
        repeatMode: PlaybackRepeatMode,
        isShuffleEnabled: Bool,
        traversalOrder: [UUID],
        history: [UUID],
        historyIndex: Int?
    ) {
        self.version = version
        self.baseOrder = baseOrder
        self.currentID = currentID
        self.position = position.isFinite ? max(position, 0) : 0
        self.repeatMode = repeatMode
        self.isShuffleEnabled = isShuffleEnabled
        self.traversalOrder = traversalOrder
        self.history = history
        self.historyIndex = historyIndex
    }

    init?(queue: PlaybackQueue, position: TimeInterval) {
        guard let currentID = queue.currentID else {
            return nil
        }
        self.init(
            baseOrder: queue.baseOrder,
            currentID: currentID,
            position: position,
            repeatMode: queue.repeatMode,
            isShuffleEnabled: queue.isShuffleEnabled,
            traversalOrder: queue.traversalOrder,
            history: queue.history,
            historyIndex: queue.historyIndex
        )
    }
}
