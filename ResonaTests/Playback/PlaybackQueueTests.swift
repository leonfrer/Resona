import Foundation
import Testing
@testable import Resona

struct PlaybackQueueTests {
    @Test func restorationSanitizesMissingAndInconsistentState() {
        let first = UUID()
        let current = UUID()
        let missing = UUID()
        let snapshot = PlaybackRestorationSnapshot(
            baseOrder: [first, missing, current, first],
            currentID: current,
            position: -.infinity,
            repeatMode: .all,
            isShuffleEnabled: true,
            traversalOrder: [missing, current],
            history: [missing, first],
            historyIndex: 99
        )

        let queue = PlaybackQueue(
            restoring: snapshot,
            validIDs: [first, current]
        )

        #expect(queue?.baseOrder == [first, current])
        #expect(queue?.traversalOrder == [current, first])
        #expect(queue?.currentID == current)
        #expect(queue?.history == [first, current])
        #expect(queue?.historyIndex == 1)
        #expect(snapshot.position == 0)
    }

    @Test func initializationPreservesUniqueOrderAndSelectedIdentity() {
        let first = UUID()
        let selected = UUID()
        let queue = PlaybackQueue(
            ids: [first, first],
            currentID: selected
        )

        #expect(queue.baseOrder == [first, selected])
        #expect(queue.traversalOrder == [first, selected])
        #expect(queue.currentID == selected)
        #expect(queue.history == [selected])
    }

    @Test func baseOrderNavigationHonorsBoundariesAndRepeatAll() {
        let ids = [UUID(), UUID(), UUID()]
        var queue = PlaybackQueue(ids: ids, currentID: ids[1])

        #expect(queue.candidateIDs(for: .next) == [ids[2]])
        #expect(queue.candidateIDs(for: .previous) == [ids[0]])

        queue.commitNavigation(to: ids[2], direction: .next)
        #expect(queue.candidateIDs(for: .next).isEmpty)

        queue.repeatMode = .all
        #expect(queue.candidateIDs(for: .next) == [ids[0], ids[1]])
        #expect(queue.candidateIDs(for: .previous) == [ids[1], ids[0]])
    }

    @Test func repeatOneAffectsNaturalEndButNotManualCommands() {
        let ids = [UUID(), UUID(), UUID()]
        var queue = PlaybackQueue(ids: ids, currentID: ids[1])
        queue.repeatMode = .one

        #expect(
            queue.candidateIDs(for: .next, isNaturalEnd: true) == [ids[1]]
        )
        #expect(queue.candidateIDs(for: .next) == [ids[2]])
        #expect(queue.candidateIDs(for: .previous) == [ids[0]])
    }

    @Test func shuffleKeepsCurrentAndCreatesStableTraversal() {
        let ids = [UUID(), UUID(), UUID(), UUID()]
        var queue = PlaybackQueue(ids: ids, currentID: ids[2])
        var generator = PlaybackQueueTestRandomNumberGenerator()

        queue.setShuffleEnabled(true, using: &generator)
        let shuffledOrder = queue.traversalOrder

        #expect(queue.isShuffleEnabled)
        #expect(shuffledOrder.first == ids[2])
        #expect(Set(shuffledOrder) == Set(ids))
        #expect(queue.candidateIDs(for: .next) == Array(shuffledOrder.dropFirst()))
        #expect(queue.traversalOrder == shuffledOrder)

        queue.setShuffleEnabled(false, using: &generator)
        #expect(queue.traversalOrder == ids)
        #expect(queue.currentID == ids[2])
    }

    @Test func previousAndNextWalkActualHistoryBeforeTraversal() {
        let ids = [UUID(), UUID(), UUID(), UUID()]
        var queue = PlaybackQueue(ids: ids, currentID: ids[1])

        queue.commitNavigation(to: ids[2], direction: .next)
        queue.commitNavigation(to: ids[3], direction: .next)
        queue.commitNavigation(to: ids[2], direction: .previous)

        #expect(queue.currentID == ids[2])
        #expect(queue.candidateIDs(for: .next).first == ids[3])
        #expect(queue.candidateIDs(for: .previous).first == ids[1])
    }

    @Test func removalPurgesOrdersAndHistoryWithoutRetargetingCurrent() {
        let ids = [UUID(), UUID(), UUID()]
        var queue = PlaybackQueue(ids: ids, currentID: ids[0])
        queue.commitNavigation(to: ids[1], direction: .next)
        queue.commitNavigation(to: ids[2], direction: .next)

        queue.remove(id: ids[1])

        #expect(queue.baseOrder == [ids[0], ids[2]])
        #expect(queue.traversalOrder == [ids[0], ids[2]])
        #expect(queue.history == [ids[0], ids[2]])
        #expect(queue.currentID == ids[2])

        queue.remove(id: ids[2])
        #expect(queue.currentID == nil)
        #expect(queue.history.isEmpty)
        #expect(queue.historyIndex == nil)
    }

    @Test func repeatAllSingleItemCanWrapToItself() {
        let id = UUID()
        var queue = PlaybackQueue(ids: [id], currentID: id)
        queue.repeatMode = .all

        #expect(queue.candidateIDs(for: .next) == [id])
        #expect(queue.candidateIDs(for: .previous) == [id])
    }
}

private struct PlaybackQueueTestRandomNumberGenerator: RandomNumberGenerator {
    private var value: UInt64 = 0

    mutating func next() -> UInt64 {
        defer { value &+= 1 }
        return value
    }
}
