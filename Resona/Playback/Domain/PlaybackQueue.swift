import Foundation

nonisolated enum PlaybackQueueDirection: Sendable {
    case next
    case previous
}

nonisolated struct PlaybackQueue: Equatable, Sendable {
    private(set) var baseOrder: [UUID]
    private(set) var traversalOrder: [UUID]
    private(set) var currentID: UUID?
    private(set) var history: [UUID]
    private(set) var historyIndex: Int?
    private(set) var isShuffleEnabled: Bool
    var repeatMode: PlaybackRepeatMode

    init(
        ids: [UUID],
        currentID: UUID,
        repeatMode: PlaybackRepeatMode = .off
    ) {
        var uniqueIDs = Self.unique(ids)
        if !uniqueIDs.contains(currentID) {
            uniqueIDs.append(currentID)
        }

        baseOrder = uniqueIDs
        traversalOrder = uniqueIDs
        self.currentID = currentID
        history = [currentID]
        historyIndex = 0
        isShuffleEnabled = false
        self.repeatMode = repeatMode
    }

    init?(
        restoring snapshot: PlaybackRestorationSnapshot,
        validIDs: Set<UUID>
    ) {
        let baseOrder = Self.unique(snapshot.baseOrder)
            .filter(validIDs.contains)
        guard baseOrder.contains(snapshot.currentID) else {
            return nil
        }

        self.baseOrder = baseOrder
        currentID = snapshot.currentID
        repeatMode = snapshot.repeatMode
        isShuffleEnabled = snapshot.isShuffleEnabled

        if snapshot.isShuffleEnabled {
            let restoredTraversal = Self.unique(snapshot.traversalOrder)
                .filter { validIDs.contains($0) && baseOrder.contains($0) }
            traversalOrder = restoredTraversal
                + baseOrder.filter { !restoredTraversal.contains($0) }
        } else {
            traversalOrder = baseOrder
        }

        history = snapshot.history.filter {
            validIDs.contains($0) && baseOrder.contains($0)
        }
        if let restoredIndex = snapshot.historyIndex,
           history.indices.contains(restoredIndex),
           history[restoredIndex] == snapshot.currentID {
            historyIndex = restoredIndex
        } else if let currentIndex = history.lastIndex(of: snapshot.currentID) {
            historyIndex = currentIndex
        } else {
            history.append(snapshot.currentID)
            historyIndex = history.index(before: history.endIndex)
        }
        trimHistoryIfNeeded()
    }

    var isEmpty: Bool {
        baseOrder.isEmpty
    }

    var restorationCandidateIDs: [UUID] {
        guard let currentID,
              let currentIndex = traversalOrder.firstIndex(of: currentID) else {
            return []
        }
        return [currentID]
            + Array(traversalOrder.dropFirst(currentIndex + 1))
            + Array(traversalOrder[..<currentIndex])
    }

    mutating func setShuffleEnabled<R: RandomNumberGenerator>(
        _ isEnabled: Bool,
        using randomNumberGenerator: inout R
    ) {
        guard isEnabled != isShuffleEnabled,
              let currentID else {
            return
        }

        if isEnabled {
            var remainingIDs = baseOrder.filter { $0 != currentID }
            remainingIDs.shuffle(using: &randomNumberGenerator)
            traversalOrder = [currentID] + remainingIDs
        } else {
            traversalOrder = baseOrder
        }

        isShuffleEnabled = isEnabled
        history = [currentID]
        historyIndex = 0
    }

    func candidateIDs(
        for direction: PlaybackQueueDirection,
        isNaturalEnd: Bool = false
    ) -> [UUID] {
        guard let currentID,
              !traversalOrder.isEmpty else {
            return []
        }

        if isNaturalEnd, repeatMode == .one {
            return [currentID]
        }

        let historyCandidates = historyCandidates(for: direction)
        let traversalCandidates = traversalCandidates(for: direction)
        return Self.unique(historyCandidates + traversalCandidates)
    }

    mutating func commitNavigation(
        to id: UUID,
        direction: PlaybackQueueDirection
    ) {
        guard traversalOrder.contains(id),
              id != currentID,
              let historyIndex else {
            return
        }

        switch direction {
        case .next:
            let forwardRange = history.index(after: historyIndex) ..< history.endIndex
            if let index = history[forwardRange].firstIndex(of: id) {
                self.historyIndex = index
            } else {
                history.removeSubrange(forwardRange)
                history.append(id)
                self.historyIndex = history.index(before: history.endIndex)
                trimHistoryIfNeeded()
            }
        case .previous:
            let earlierHistory = history[..<historyIndex]
            if let index = earlierHistory.lastIndex(of: id) {
                self.historyIndex = index
            } else {
                history.insert(id, at: historyIndex)
                self.historyIndex = historyIndex
                trimHistoryIfNeeded()
            }
        }

        currentID = id
    }

    mutating func remove(id: UUID) {
        baseOrder.removeAll { $0 == id }
        traversalOrder.removeAll { $0 == id }

        guard currentID != id else {
            currentID = nil
            history = []
            historyIndex = nil
            return
        }

        guard let historyIndex else {
            history.removeAll { $0 == id }
            return
        }

        let removedBeforeCurrent = history[..<historyIndex]
            .filter { $0 == id }
            .count
        history.removeAll { $0 == id }
        self.historyIndex = max(historyIndex - removedBeforeCurrent, 0)
    }

    private func historyCandidates(
        for direction: PlaybackQueueDirection
    ) -> [UUID] {
        guard let historyIndex else {
            return []
        }

        return switch direction {
        case .next:
            Array(history.dropFirst(historyIndex + 1))
        case .previous:
            Array(history[..<historyIndex].reversed())
        }
    }

    private func traversalCandidates(
        for direction: PlaybackQueueDirection
    ) -> [UUID] {
        guard let currentID,
              let currentIndex = traversalOrder.firstIndex(of: currentID) else {
            return []
        }

        let candidates: [UUID]
        switch direction {
        case .next:
            candidates = Array(traversalOrder.dropFirst(currentIndex + 1))
                + wrappedNextCandidates(before: currentIndex)
        case .previous:
            candidates = Array(traversalOrder[..<currentIndex].reversed())
                + wrappedPreviousCandidates(after: currentIndex)
        }

        if candidates.isEmpty,
           repeatMode == .all,
           traversalOrder.count == 1 {
            return [currentID]
        }
        return candidates
    }

    private func wrappedNextCandidates(before currentIndex: Int) -> [UUID] {
        guard repeatMode == .all else {
            return []
        }
        return Array(traversalOrder[..<currentIndex])
    }

    private func wrappedPreviousCandidates(after currentIndex: Int) -> [UUID] {
        guard repeatMode == .all else {
            return []
        }
        return Array(traversalOrder.dropFirst(currentIndex + 1).reversed())
    }

    private mutating func trimHistoryIfNeeded() {
        let maximumCount = max(baseOrder.count, 1)
        guard history.count > maximumCount,
              let historyIndex else {
            return
        }

        let overflow = history.count - maximumCount
        if historyIndex >= overflow {
            history.removeFirst(overflow)
            self.historyIndex = historyIndex - overflow
        } else {
            history.removeLast(overflow)
        }
    }

    private static func unique(_ ids: [UUID]) -> [UUID] {
        var seen: Set<UUID> = []
        return ids.filter { seen.insert($0).inserted }
    }
}
