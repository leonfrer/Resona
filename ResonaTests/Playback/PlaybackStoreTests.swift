import Foundation
import Testing
@testable import Resona

@MainActor
struct PlaybackStoreTests {
    @Test func selectingAvailableSongStartsAtZero() async {
        let item = playbackItem(title: "First")
        let provider = PlaybackStoreTestProvider(items: [item.id: item])
        let engine = PlaybackStoreTestEngine(duration: 120)
        let session = PlaybackStoreTestAudioSession()
        let store = PlaybackStore(
            itemProvider: provider,
            engine: engine,
            audioSession: session
        )

        await store.select(songID: item.id)

        #expect(store.currentItem == item)
        #expect(store.phase == .playing)
        #expect(store.position == 0)
        #expect(store.duration == 120)
        #expect(engine.preparedURLs == [availableURL(for: item)])
        #expect(engine.playedSessionIDs.count == 1)
        #expect(session.activationCount == 1)
    }

    @Test func unavailableAndMissingSongsNeverClaimPlayback() async {
        let unavailable = playbackItem(
            title: "Unavailable",
            availability: .unavailable
        )
        let provider = PlaybackStoreTestProvider(
            items: [unavailable.id: unavailable]
        )
        let engine = PlaybackStoreTestEngine()
        let store = PlaybackStore(
            itemProvider: provider,
            engine: engine,
            audioSession: PlaybackStoreTestAudioSession()
        )

        await store.select(songID: unavailable.id)
        #expect(store.currentItem == unavailable)
        #expect(store.phase == .failed(.resourceUnavailable))
        #expect(engine.preparedURLs.isEmpty)

        await store.select(songID: UUID())
        #expect(store.currentItem == nil)
        #expect(store.phase == .idle)
        #expect(engine.playedSessionIDs.isEmpty)
    }

    @Test func pauseResumeAndSeekKeepOneConsistentPhase() async {
        let item = playbackItem(title: "Transport")
        let engine = PlaybackStoreTestEngine(duration: 100)
        let session = PlaybackStoreTestAudioSession()
        let store = PlaybackStore(
            itemProvider: PlaybackStoreTestProvider(items: [item.id: item]),
            engine: engine,
            audioSession: session
        )
        await store.select(songID: item.id)
        engine.position = 25

        store.pause()
        #expect(store.phase == .paused)
        #expect(store.position == 25)
        #expect(session.deactivationCount == 1)

        store.seek(to: -10)
        #expect(store.position == 0)
        store.play()
        #expect(store.phase == .playing)

        store.seek(to: 150)
        #expect(store.position == 100)
        #expect(store.phase == .stoppedAtEnd)
        store.seek(to: 40)
        #expect(store.position == 40)
        #expect(store.phase == .paused)
    }

    @Test func seekWithinSliderPrecisionOfEndStopsAtExactDuration() async {
        let item = playbackItem(title: "Slider Precision")
        let store = PlaybackStore(
            itemProvider: PlaybackStoreTestProvider(items: [item.id: item]),
            engine: PlaybackStoreTestEngine(duration: 100),
            audioSession: PlaybackStoreTestAudioSession()
        )
        await store.select(songID: item.id)

        store.seek(to: 99.99)

        #expect(store.position == 100)
        #expect(store.phase == .stoppedAtEnd)
    }

    @Test func naturalEndRetainsItemAndNextPlayRestartsAtZero() async {
        let item = playbackItem(title: "Ending")
        let engine = PlaybackStoreTestEngine(duration: 60)
        let store = PlaybackStore(
            itemProvider: PlaybackStoreTestProvider(items: [item.id: item]),
            engine: engine,
            audioSession: PlaybackStoreTestAudioSession()
        )
        await store.select(songID: item.id)
        let sessionID = engine.latestSessionID

        engine.emit(.finished(sessionID: sessionID))
        await settleAsyncEvents()

        #expect(store.currentItem?.id == item.id)
        #expect(store.position == 60)
        #expect(store.phase == .stoppedAtEnd)

        store.play()
        #expect(engine.seekRequests.last?.seconds == 0)
        #expect(store.position == 0)
        #expect(store.phase == .playing)
    }

    @Test func replacementIgnoresEventsFromOldSession() async {
        let first = playbackItem(title: "First")
        let second = playbackItem(title: "Second")
        let engine = PlaybackStoreTestEngine(duration: 90)
        let store = PlaybackStore(
            itemProvider: PlaybackStoreTestProvider(
                items: [first.id: first, second.id: second]
            ),
            engine: engine,
            audioSession: PlaybackStoreTestAudioSession()
        )
        await store.select(songID: first.id)
        let firstSessionID = engine.latestSessionID
        await store.select(songID: second.id)

        engine.emit(.position(sessionID: firstSessionID, seconds: 80))
        engine.emit(.finished(sessionID: firstSessionID))
        engine.emit(.decodingFailed(sessionID: firstSessionID))
        await settleAsyncEvents()

        #expect(store.currentItem?.id == second.id)
        #expect(store.position == 0)
        #expect(store.phase == .playing)
        #expect(engine.stopCount >= 1)
    }

    @Test func laterSelectionWinsWhenEarlierLookupFinishesLast() async {
        let first = playbackItem(title: "Slow First")
        let second = playbackItem(title: "Fast Second")
        let provider = ControlledPlaybackStoreTestProvider()
        let store = PlaybackStore(
            itemProvider: provider,
            engine: PlaybackStoreTestEngine(),
            audioSession: PlaybackStoreTestAudioSession()
        )

        let firstSelection = Task {
            await store.select(songID: first.id)
        }
        await provider.waitForRequest(songID: first.id)
        let secondSelection = Task {
            await store.select(songID: second.id)
        }
        await provider.waitForRequest(songID: second.id)

        await provider.resolve(songID: second.id, item: second)
        await secondSelection.value
        await provider.resolve(songID: first.id, item: first)
        await firstSelection.value

        #expect(store.currentItem?.id == second.id)
        #expect(store.phase == .playing)
    }

    @Test func removalInvalidationStopsAndClearsMatchingCurrentSong() async {
        let item = playbackItem(title: "Current")
        let engine = PlaybackStoreTestEngine(duration: 75)
        let session = PlaybackStoreTestAudioSession()
        let store = PlaybackStore(
            itemProvider: PlaybackStoreTestProvider(items: [item.id: item]),
            engine: engine,
            audioSession: session
        )
        await store.select(songID: item.id)
        engine.position = 30
        let stopCountBeforeInvalidation = engine.stopCount

        store.beginRemovalInvalidation(for: item.id)

        #expect(store.currentItem == nil)
        #expect(store.phase == .idle)
        #expect(store.position == 0)
        #expect(store.duration == nil)
        #expect(store.pendingSelectionID == nil)
        #expect(!store.canSeek)
        #expect(engine.stopCount == stopCountBeforeInvalidation + 1)
        #expect(session.deactivationCount == 1)
    }

    @Test func removalInvalidationPreservesUnrelatedPlayback() async {
        let current = playbackItem(title: "Current")
        let removedID = UUID()
        let engine = PlaybackStoreTestEngine(duration: 80)
        let session = PlaybackStoreTestAudioSession()
        let store = PlaybackStore(
            itemProvider: PlaybackStoreTestProvider(
                items: [current.id: current]
            ),
            engine: engine,
            audioSession: session
        )
        await store.select(songID: current.id)
        let sessionID = engine.latestSessionID
        let stopCountBeforeInvalidation = engine.stopCount

        store.beginRemovalInvalidation(for: removedID)

        #expect(store.currentItem == current)
        #expect(store.phase == .playing)
        #expect(store.position == 0)
        #expect(store.duration == 80)
        #expect(engine.latestSessionID == sessionID)
        #expect(engine.stopCount == stopCountBeforeInvalidation)
        #expect(session.deactivationCount == 0)
    }

    @Test func blockedSelectionIsRejectedUntilRemovalInvalidationEnds() async {
        let current = playbackItem(title: "Current")
        let blocked = playbackItem(title: "Blocked")
        let provider = PlaybackStoreTestProvider(
            items: [current.id: current, blocked.id: blocked]
        )
        let engine = PlaybackStoreTestEngine()
        let store = PlaybackStore(
            itemProvider: provider,
            engine: engine,
            audioSession: PlaybackStoreTestAudioSession()
        )
        await store.select(songID: current.id)
        let preparedURLsBeforeBlockedSelection = engine.preparedURLs

        store.beginRemovalInvalidation(for: blocked.id)
        await store.select(songID: blocked.id)

        #expect(store.currentItem == current)
        #expect(store.phase == .playing)
        #expect(engine.preparedURLs == preparedURLsBeforeBlockedSelection)

        store.endRemovalInvalidation(for: blocked.id)
        await store.select(songID: blocked.id)

        #expect(store.currentItem == blocked)
        #expect(store.phase == .playing)
        #expect(engine.preparedURLs.last == availableURL(for: blocked))
    }

    @Test func staleSelectionCannotRecreateSongAfterRemovalBegins() async {
        let item = playbackItem(title: "Resolving")
        let provider = ControlledPlaybackStoreTestProvider()
        let engine = PlaybackStoreTestEngine()
        let store = PlaybackStore(
            itemProvider: provider,
            engine: engine,
            audioSession: PlaybackStoreTestAudioSession()
        )

        let selection = Task {
            await store.select(songID: item.id)
        }
        await provider.waitForRequest(songID: item.id)

        store.beginRemovalInvalidation(for: item.id)
        #expect(store.pendingSelectionID == nil)
        #expect(store.phase == .idle)

        await provider.resolve(songID: item.id, item: item)
        await selection.value

        #expect(store.currentItem == nil)
        #expect(store.phase == .idle)
        #expect(store.position == 0)
        #expect(store.duration == nil)
        #expect(engine.preparedURLs.isEmpty)
        #expect(engine.playedSessionIDs.isEmpty)
    }

    @Test func failuresAndInterruptionStopClaimingPlayback() async {
        let item = playbackItem(title: "Failure")
        let engine = PlaybackStoreTestEngine(duration: 45)
        let session = PlaybackStoreTestAudioSession()
        let store = PlaybackStore(
            itemProvider: PlaybackStoreTestProvider(items: [item.id: item]),
            engine: engine,
            audioSession: session
        )
        await store.select(songID: item.id)
        let firstSessionID = engine.latestSessionID

        engine.emit(.stoppedUnexpectedly(sessionID: firstSessionID))
        await settleAsyncEvents()
        #expect(store.phase == .failed(.playbackFailed))

        await store.retry()
        #expect(store.phase == .playing)
        session.emit(.interruptionBegan)
        await settleAsyncEvents()
        #expect(store.phase == .paused)
    }

    @Test func activationAndEngineFailuresMapToTypedFailures() async {
        let item = playbackItem(title: "Startup")
        let activationFailure = PlaybackStoreTestAudioSession()
        activationFailure.shouldFailActivation = true
        let activationStore = PlaybackStore(
            itemProvider: PlaybackStoreTestProvider(items: [item.id: item]),
            engine: PlaybackStoreTestEngine(),
            audioSession: activationFailure
        )
        await activationStore.select(songID: item.id)
        #expect(activationStore.phase == .failed(.startupFailed))

        let invalidEngine = PlaybackStoreTestEngine()
        invalidEngine.shouldFailPreparation = true
        let invalidStore = PlaybackStore(
            itemProvider: PlaybackStoreTestProvider(items: [item.id: item]),
            engine: invalidEngine,
            audioSession: PlaybackStoreTestAudioSession()
        )
        await invalidStore.select(songID: item.id)
        #expect(invalidStore.phase == .failed(.resourceInvalid))
    }
}

@MainActor
private final class PlaybackStoreTestEngine: AudioPlaybackEngine {
    let events: AsyncStream<AudioPlaybackEvent>
    let eventContinuation: AsyncStream<AudioPlaybackEvent>.Continuation
    var duration: TimeInterval
    var position: TimeInterval = 0
    var shouldFailPreparation = false
    var shouldFailPlayback = false
    private(set) var preparedURLs: [URL] = []
    private(set) var playedSessionIDs: [UUID] = []
    private(set) var pausedSessionIDs: [UUID] = []
    private(set) var seekRequests: [(seconds: TimeInterval, sessionID: UUID)] = []
    private(set) var stopCount = 0
    private(set) var latestSessionID = UUID()

    init(duration: TimeInterval = 90) {
        self.duration = duration
        (events, eventContinuation) = AsyncStream.makeStream()
    }

    func prepare(url: URL) throws -> AudioPlaybackPreparation {
        preparedURLs.append(url)
        if shouldFailPreparation {
            throw AudioPlaybackEngineError.resourceInvalid
        }
        latestSessionID = UUID()
        position = 0
        return AudioPlaybackPreparation(
            sessionID: latestSessionID,
            duration: duration
        )
    }

    func play(sessionID: UUID) throws {
        if shouldFailPlayback {
            throw AudioPlaybackEngineError.startupFailed
        }
        playedSessionIDs.append(sessionID)
    }

    func pause(sessionID: UUID) {
        pausedSessionIDs.append(sessionID)
    }

    func seek(to seconds: TimeInterval, sessionID: UUID) {
        position = seconds
        seekRequests.append((seconds, sessionID))
    }

    func currentPosition(sessionID: UUID) -> TimeInterval? { position }

    func stop() {
        stopCount += 1
    }

    func emit(_ event: AudioPlaybackEvent) {
        eventContinuation.yield(event)
    }
}

@MainActor
private final class PlaybackStoreTestAudioSession: AudioSessionControlling {
    let events: AsyncStream<AudioSessionEvent>
    let eventContinuation: AsyncStream<AudioSessionEvent>.Continuation
    var shouldFailActivation = false
    private(set) var activationCount = 0
    private(set) var deactivationCount = 0

    init() {
        (events, eventContinuation) = AsyncStream.makeStream()
    }

    func activate() throws {
        activationCount += 1
        if shouldFailActivation {
            throw PlaybackStoreTestError.activationFailed
        }
    }

    func deactivate() throws {
        deactivationCount += 1
    }

    func emit(_ event: AudioSessionEvent) {
        eventContinuation.yield(event)
    }
}

private actor PlaybackStoreTestProvider: PlaybackItemProviding {
    let items: [UUID: PlaybackItem]

    init(items: [UUID: PlaybackItem]) {
        self.items = items
    }

    func item(for songID: UUID) -> PlaybackItem? {
        items[songID]
    }
}

private actor ControlledPlaybackStoreTestProvider: PlaybackItemProviding {
    private var requests: Set<UUID> = []
    private var continuations: [UUID: CheckedContinuation<PlaybackItem?, Never>] = [:]

    func item(for songID: UUID) async -> PlaybackItem? {
        requests.insert(songID)
        return await withCheckedContinuation { continuation in
            continuations[songID] = continuation
        }
    }

    func waitForRequest(songID: UUID) async {
        while !requests.contains(songID) {
            await Task.yield()
        }
    }

    func resolve(songID: UUID, item: PlaybackItem?) {
        continuations.removeValue(forKey: songID)?.resume(returning: item)
    }
}

private enum PlaybackStoreTestError: Error {
    case activationFailed
}

private func playbackItem(
    title: String,
    availability: SongAvailability? = nil
) -> PlaybackItem {
    let id = UUID()
    return PlaybackItem(
        id: id,
        title: title,
        artist: "Artist",
        album: "Album",
        artworkURL: nil,
        availability: availability
            ?? .available(audioURL: URL(filePath: "/managed/\(id).m4a")),
        libraryDurationSeconds: 100
    )
}

private func availableURL(for item: PlaybackItem) -> URL {
    guard case let .available(url) = item.availability else {
        Issue.record("Expected an available item")
        return URL(filePath: "/invalid")
    }
    return url
}

@MainActor
private func settleAsyncEvents() async {
    for _ in 0 ..< 5 {
        await Task.yield()
    }
}
