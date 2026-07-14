import Foundation
import Observation

@MainActor
@Observable
final class PlaybackStore: PlaybackRemovalInvalidating {
    private(set) var currentItem: PlaybackItem? {
        didSet {
            publishSystemState()
            scheduleRestorationWrite(force: true)
        }
    }
    private(set) var phase: PlaybackPhase {
        didSet {
            publishSystemState()
            scheduleRestorationWrite(force: true)
        }
    }
    private(set) var position: TimeInterval {
        didSet {
            publishSystemState()
            scheduleRestorationWrite(force: false)
        }
    }
    private(set) var duration: TimeInterval? {
        didSet {
            publishSystemState()
            scheduleRestorationWrite(force: true)
        }
    }
    private(set) var pendingSelectionID: UUID? {
        didSet { publishSystemState() }
    }
    private(set) var queue: PlaybackQueue? {
        didSet {
            publishSystemState()
            scheduleRestorationWrite(force: true)
        }
    }
    private(set) var queueItems: [UUID: PlaybackItem] = [:]
    private(set) var isLoadingQueueItems = false

    private let itemProvider: any PlaybackItemProviding
    private let engine: any AudioPlaybackEngine
    private let audioSession: any AudioSessionControlling
    private let nowPlayingController: any NowPlayingControlling
    private let remoteCommandController: any RemoteCommandControlling
    private let restorationCoordinator: PlaybackRestorationCoordinator?
    nonisolated private let eventTasks = PlaybackEventTasks()
    private var activeSessionID: UUID? {
        didSet { publishSystemState() }
    }
    private var blockedSelectionIDs: Set<UUID> = []
    private var selectionGeneration = UUID()
    private var failedQueueNavigation: FailedQueueNavigation?
    private var queueLoadGeneration = UUID()
    private var wasPlayingBeforeInterruption = false
    private var didAttemptRestoration = false
    private var allowsRestorationWrites = false
    private var restorationSequence = 0
    private var lastScheduledRestorationPosition: TimeInterval?

    init(
        itemProvider: any PlaybackItemProviding,
        engine: any AudioPlaybackEngine,
        audioSession: any AudioSessionControlling,
        nowPlayingController: (any NowPlayingControlling)? = nil,
        remoteCommandController: (any RemoteCommandControlling)? = nil,
        restorationStore: (any PlaybackRestoring)? = nil,
        initialItem: PlaybackItem? = nil,
        initialPhase: PlaybackPhase = .idle,
        initialPosition: TimeInterval = 0,
        initialDuration: TimeInterval? = nil
    ) {
        self.itemProvider = itemProvider
        self.engine = engine
        self.audioSession = audioSession
        self.nowPlayingController =
            nowPlayingController ?? NullNowPlayingController()
        self.remoteCommandController =
            remoteCommandController ?? NullRemoteCommandController()
        restorationCoordinator = restorationStore.map {
            PlaybackRestorationCoordinator(store: $0)
        }
        currentItem = initialItem
        phase = initialPhase
        position = initialPosition
        duration = initialDuration
        queue = initialItem.map {
            PlaybackQueue(ids: [$0.id], currentID: $0.id)
        }

        let engineEvents = engine.events
        let engineEventTask = Task { [weak self] in
            for await event in engineEvents {
                self?.handleEngineEvent(event)
            }
        }
        eventTasks.store(engineEventTask)

        let audioSessionEvents = audioSession.events
        let audioSessionEventTask = Task { [weak self] in
            for await event in audioSessionEvents {
                self?.handleAudioSessionEvent(event)
            }
        }
        eventTasks.store(audioSessionEventTask)

        self.remoteCommandController.install { [weak self] command in
            self?.handleRemoteCommand(command) ?? false
        }
        publishSystemState()
    }

    deinit {
        eventTasks.cancelAll()
    }

    var canSeek: Bool {
        guard let duration, duration.isFinite, duration > 0,
              activeSessionID != nil else {
            return false
        }
        return switch phase {
        case .playing, .paused, .stoppedAtEnd:
            true
        case .idle, .preparing, .failed:
            false
        }
    }

    var canGoNext: Bool {
        queue?.candidateIDs(for: .next).isEmpty == false
    }

    var canGoPrevious: Bool {
        queue?.candidateIDs(for: .previous).isEmpty == false
    }

    var queuedItemsInTraversalOrder: [PlaybackItem] {
        guard let queue else {
            return []
        }
        return queue.traversalOrder.compactMap { queueItems[$0] }
    }

    func select(songID: UUID) async {
        await select(songID: songID, queueIDs: [songID])
    }

    func select(songID: UUID, queueIDs: [UUID]) async {
        guard !blockedSelectionIDs.contains(songID),
              pendingSelectionID != songID else {
            return
        }

        let repeatMode = queue?.repeatMode ?? .off
        let wasShuffleEnabled = queue?.isShuffleEnabled == true
        var replacementQueue = PlaybackQueue(
            ids: queueIDs,
            currentID: songID,
            repeatMode: repeatMode
        )
        if wasShuffleEnabled {
            var randomNumberGenerator = SystemRandomNumberGenerator()
            replacementQueue.setShuffleEnabled(
                true,
                using: &randomNumberGenerator
            )
        }
        queue = replacementQueue
        queueItems = [:]
        queueLoadGeneration = UUID()
        isLoadingQueueItems = false
        failedQueueNavigation = nil
        await prepareSelection(songID: songID, clearsCurrentItem: true)
    }

    func next() async {
        await navigateQueue(direction: .next, isNaturalEnd: false)
    }

    func previous() async {
        await navigateQueue(direction: .previous, isNaturalEnd: false)
    }

    func cycleRepeatMode() {
        guard var queue else {
            return
        }
        queue.repeatMode.cycle()
        self.queue = queue
    }

    func toggleShuffle() {
        guard var queue else {
            return
        }
        var randomNumberGenerator = SystemRandomNumberGenerator()
        queue.setShuffleEnabled(
            !queue.isShuffleEnabled,
            using: &randomNumberGenerator
        )
        self.queue = queue
    }

    func loadQueueItems() async {
        guard let queue else {
            queueItems = [:]
            return
        }
        let requestedIDs = queue.baseOrder
        let generation = UUID()
        queueLoadGeneration = generation
        isLoadingQueueItems = true
        defer {
            if queueLoadGeneration == generation {
                isLoadingQueueItems = false
            }
        }

        let resolvedItems: [PlaybackItem]
        do {
            resolvedItems = try await itemProvider.items(for: requestedIDs)
        } catch {
            return
        }
        guard self.queue?.baseOrder == requestedIDs else {
            return
        }

        queueItems = Dictionary(
            uniqueKeysWithValues: resolvedItems.map { ($0.id, $0) }
        )
        if let currentItem {
            queueItems[currentItem.id] = currentItem
        }

        var resolvedIDs = Set(resolvedItems.map(\.id))
        if let currentItem {
            resolvedIDs.insert(currentItem.id)
        }
        for missingID in requestedIDs where !resolvedIDs.contains(missingID) {
            self.queue?.remove(id: missingID)
        }
    }

    private func prepareSelection(
        songID: UUID,
        clearsCurrentItem: Bool
    ) async {

        let generation = UUID()
        selectionGeneration = generation
        pendingSelectionID = songID
        stopActivePlayback()
        if clearsCurrentItem {
            currentItem = nil
            position = 0
            duration = nil
        }
        phase = .preparing

        defer {
            if selectionGeneration == generation {
                pendingSelectionID = nil
            }
        }

        let resolvedItem: PlaybackItem?
        do {
            resolvedItem = try await itemProvider.item(for: songID)
        } catch {
            resolvedItem = nil
        }

        guard selectionGeneration == generation else {
            return
        }
        guard let resolvedItem else {
            if clearsCurrentItem {
                currentItem = nil
                phase = .idle
            } else {
                phase = .failed(.resourceUnavailable)
            }
            return
        }

        currentItem = resolvedItem
        queueItems[resolvedItem.id] = resolvedItem
        guard case let .available(audioURL) = resolvedItem.availability else {
            phase = .failed(.resourceUnavailable)
            return
        }

        let preparation: AudioPlaybackPreparation
        do {
            preparation = try engine.prepare(url: audioURL)
        } catch {
            engine.stop()
            try? audioSession.deactivate()
            phase = .failed(.resourceInvalid)
            return
        }

        guard preparation.duration.isFinite, preparation.duration > 0 else {
            engine.stop()
            phase = .failed(.resourceInvalid)
            return
        }
        activeSessionID = preparation.sessionID
        duration = preparation.duration
        position = 0
        startPreparedPlayback()
    }

    func beginRemovalInvalidation(for songID: UUID) async throws {
        blockedSelectionIDs.insert(songID)
        queue?.remove(id: songID)
        queueItems.removeValue(forKey: songID)
        if queue?.isEmpty == true {
            queue = nil
        }

        if pendingSelectionID == songID {
            selectionGeneration = UUID()
            pendingSelectionID = nil
            if phase == .preparing {
                phase = currentItem == nil
                    ? .idle
                    : .failed(.queueUnavailable)
            }
        }

        guard currentItem?.id == songID else {
            try await flushRestorationThrowing()
            return
        }
        stopActivePlayback()
        clearCurrentPlaybackState()
        try await flushRestorationThrowing()
    }

    func endRemovalInvalidation(for songID: UUID) {
        blockedSelectionIDs.remove(songID)
    }

    func play() {
        guard let sessionID = activeSessionID else {
            return
        }

        switch phase {
        case .paused:
            break
        case .stoppedAtEnd:
            engine.seek(to: 0, sessionID: sessionID)
            position = 0
        case .idle, .preparing, .playing, .failed:
            return
        }

        startPreparedPlayback()
    }

    func pause() {
        guard phase == .playing,
              let sessionID = activeSessionID else {
            return
        }
        synchronizePosition(sessionID: sessionID)
        engine.pause(sessionID: sessionID)
        try? audioSession.deactivate()
        phase = .paused
    }

    func seek(to requestedPosition: TimeInterval) {
        guard canSeek,
              let sessionID = activeSessionID,
              let duration else {
            return
        }

        let target = min(max(requestedPosition, 0), duration)
        let isAtEnd = duration - target <= min(duration, 0.05)
        if isAtEnd {
            engine.pause(sessionID: sessionID)
            engine.seek(to: target, sessionID: sessionID)
            try? audioSession.deactivate()
            position = duration
            phase = .stoppedAtEnd
            return
        }

        engine.seek(to: target, sessionID: sessionID)
        position = target
        if phase == .stoppedAtEnd {
            phase = .paused
        }
    }

    func retry() async {
        guard case let .failed(failure) = phase else {
            return
        }
        if failure == .queueUnavailable,
           let failedQueueNavigation {
            await navigateQueue(
                direction: failedQueueNavigation.direction,
                isNaturalEnd: failedQueueNavigation.isNaturalEnd
            )
            return
        }
        guard let songID = currentItem?.id else {
            return
        }
        await prepareSelection(songID: songID, clearsCurrentItem: false)
    }

    func synchronizePosition() {
        guard let sessionID = activeSessionID else {
            return
        }
        synchronizePosition(sessionID: sessionID)
    }

    func restore() async {
        guard !didAttemptRestoration,
              let restorationCoordinator else {
            return
        }
        didAttemptRestoration = true

        if queue != nil || currentItem != nil || pendingSelectionID != nil {
            allowsRestorationWrites = true
            await flushRestoration()
            return
        }

        let generation = UUID()
        selectionGeneration = generation

        let snapshot: PlaybackRestorationSnapshot?
        do {
            snapshot = try await restorationCoordinator.load()
        } catch {
            allowsRestorationWrites = true
            await clearPersistedRestoration()
            return
        }
        guard selectionGeneration == generation else {
            finishSupersededRestoration()
            return
        }
        guard let snapshot else {
            allowsRestorationWrites = true
            return
        }

        let resolvedItems: [PlaybackItem]
        do {
            resolvedItems = try await itemProvider.items(for: snapshot.baseOrder)
        } catch {
            await clearRestoredPlaybackState()
            return
        }
        guard selectionGeneration == generation else {
            finishSupersededRestoration()
            return
        }

        let itemsByID = Dictionary(
            uniqueKeysWithValues: resolvedItems.map { ($0.id, $0) }
        )
        guard var restoredQueue = PlaybackQueue(
            restoring: snapshot,
            validIDs: Set(itemsByID.keys)
        ) else {
            await clearRestoredPlaybackState()
            return
        }

        for candidateID in restoredQueue.restorationCandidateIDs {
            guard selectionGeneration == generation else {
                finishSupersededRestoration()
                return
            }
            guard let item = itemsByID[candidateID],
                  case let .available(audioURL) = item.availability,
                  let preparation = try? engine.prepare(url: audioURL),
                  preparation.duration.isFinite,
                  preparation.duration > 0 else {
                continue
            }

            if candidateID != restoredQueue.currentID {
                restoredQueue.commitNavigation(to: candidateID, direction: .next)
            }
            let restoredPosition = candidateID == snapshot.currentID
                ? min(snapshot.position, preparation.duration)
                : 0
            if restoredPosition > 0 {
                engine.seek(
                    to: restoredPosition,
                    sessionID: preparation.sessionID
                )
            }

            queue = restoredQueue
            queueItems = itemsByID
            currentItem = item
            activeSessionID = preparation.sessionID
            duration = preparation.duration
            position = restoredPosition
            phase = preparation.duration - restoredPosition
                <= min(preparation.duration, 0.05)
                ? .stoppedAtEnd
                : .paused
            allowsRestorationWrites = true
            await flushRestoration()
            return
        }

        await clearRestoredPlaybackState()
    }

    func flushRestoration() async {
        try? await flushRestorationThrowing()
    }

    private func startPreparedPlayback() {
        guard let sessionID = activeSessionID else {
            return
        }

        do {
            try audioSession.activate()
            try engine.play(sessionID: sessionID)
            phase = .playing
        } catch {
            engine.stop()
            activeSessionID = nil
            try? audioSession.deactivate()
            phase = .failed(.startupFailed)
        }
    }

    private func stopActivePlayback() {
        let shouldDeactivate = activeSessionID != nil || phase == .playing
        engine.stop()
        activeSessionID = nil
        if shouldDeactivate {
            try? audioSession.deactivate()
        }
    }

    private func clearCurrentPlaybackState() {
        currentItem = nil
        phase = .idle
        position = 0
        duration = nil
    }

    private func synchronizePosition(sessionID: UUID) {
        guard let duration,
              let currentPosition = engine.currentPosition(sessionID: sessionID),
              currentPosition.isFinite else {
            return
        }
        position = min(max(currentPosition, 0), duration)
    }

    private func handleEngineEvent(_ event: AudioPlaybackEvent) {
        switch event {
        case let .position(sessionID, seconds):
            guard sessionID == activeSessionID,
                  phase == .playing,
                  seconds.isFinite,
                  let duration else {
                return
            }
            position = min(max(seconds, 0), duration)
        case let .finished(sessionID):
            guard sessionID == activeSessionID else {
                return
            }
            if let duration {
                position = duration
            }
            try? audioSession.deactivate()
            phase = .stoppedAtEnd
            let finishedItemID = currentItem?.id
            if queue?.candidateIDs(
                for: .next,
                isNaturalEnd: true
            ).isEmpty == false {
                Task { [weak self] in
                    guard let self,
                          self.currentItem?.id == finishedItemID,
                          self.phase == .stoppedAtEnd else {
                        return
                    }
                    await self.navigateQueue(
                        direction: .next,
                        isNaturalEnd: true
                    )
                }
            }
        case let .decodingFailed(sessionID):
            failActiveSession(
                sessionID: sessionID,
                failure: .resourceInvalid
            )
        case let .stoppedUnexpectedly(sessionID):
            failActiveSession(
                sessionID: sessionID,
                failure: .playbackFailed
            )
        }
    }

    private func handleAudioSessionEvent(_ event: AudioSessionEvent) {
        switch event {
        case .interruptionBegan:
            wasPlayingBeforeInterruption = phase == .playing
            pause()
        case let .interruptionEnded(shouldResume):
            let shouldRestart = wasPlayingBeforeInterruption && shouldResume
            wasPlayingBeforeInterruption = false
            if shouldRestart {
                play()
            }
        case .externalOutputDisconnected:
            wasPlayingBeforeInterruption = false
            pause()
        }
    }

    private func handleRemoteCommand(_ command: PlaybackRemoteCommand) -> Bool {
        switch command {
        case .play:
            guard phase == .paused || phase == .stoppedAtEnd else {
                return false
            }
            play()
        case .pause:
            guard phase == .playing else {
                return false
            }
            pause()
        case .togglePlayPause:
            if phase == .playing {
                pause()
            } else if phase == .paused || phase == .stoppedAtEnd {
                play()
            } else {
                return false
            }
        case .next:
            guard canGoNext, pendingSelectionID == nil else {
                return false
            }
            Task { [weak self] in
                await self?.next()
            }
        case .previous:
            guard canGoPrevious, pendingSelectionID == nil else {
                return false
            }
            Task { [weak self] in
                await self?.previous()
            }
        case let .changePosition(requestedPosition):
            guard requestedPosition.isFinite, canSeek else {
                return false
            }
            seek(to: requestedPosition)
        }
        return true
    }

    private func publishSystemState() {
        let state = currentItem.map { item in
            let queueIndex = queue?.traversalOrder.firstIndex(of: item.id)
            let queueCount = queue.map(\.traversalOrder.count)
            return PlaybackSystemState(
                item: item,
                duration: duration,
                elapsedTime: position,
                playbackRate: phase == .playing ? 1 : 0,
                queueIndex: queueIndex,
                queueCount: queueCount
            )
        }
        nowPlayingController.update(state)

        let canPlay = activeSessionID != nil
            && (phase == .paused || phase == .stoppedAtEnd)
        let canPause = activeSessionID != nil && phase == .playing
        remoteCommandController.update(
            capabilities: PlaybackRemoteCapabilities(
                canPlay: canPlay,
                canPause: canPause,
                canTogglePlayPause: canPlay || canPause,
                canGoNext: canGoNext && pendingSelectionID == nil,
                canGoPrevious: canGoPrevious && pendingSelectionID == nil,
                canChangePosition: canSeek
            )
        )
    }

    private var restorationSnapshot: PlaybackRestorationSnapshot? {
        guard let queue,
              queue.currentID == currentItem?.id else {
            return nil
        }
        return PlaybackRestorationSnapshot(queue: queue, position: position)
    }

    private func scheduleRestorationWrite(force: Bool) {
        guard allowsRestorationWrites,
              let restorationCoordinator else {
            return
        }
        if !force,
           let lastScheduledRestorationPosition,
           abs(position - lastScheduledRestorationPosition) < 5 {
            return
        }

        restorationSequence += 1
        let sequence = restorationSequence
        let snapshot = restorationSnapshot
        lastScheduledRestorationPosition = snapshot?.position
        Task {
            try? await restorationCoordinator.write(
                snapshot,
                sequence: sequence
            )
        }
    }

    private func flushRestorationThrowing() async throws {
        guard allowsRestorationWrites,
              let restorationCoordinator else {
            return
        }
        restorationSequence += 1
        let sequence = restorationSequence
        let snapshot = restorationSnapshot
        lastScheduledRestorationPosition = snapshot?.position
        try await restorationCoordinator.write(snapshot, sequence: sequence)
    }

    private func clearPersistedRestoration() async {
        guard let restorationCoordinator else {
            return
        }
        restorationSequence += 1
        try? await restorationCoordinator.write(
            nil,
            sequence: restorationSequence
        )
    }

    private func clearRestoredPlaybackState() async {
        allowsRestorationWrites = true
        engine.stop()
        activeSessionID = nil
        queue = nil
        queueItems = [:]
        clearCurrentPlaybackState()
        await clearPersistedRestoration()
    }

    private func finishSupersededRestoration() {
        allowsRestorationWrites = true
        scheduleRestorationWrite(force: true)
    }

    private func failActiveSession(
        sessionID: UUID,
        failure: PlaybackFailure
    ) {
        guard sessionID == activeSessionID else {
            return
        }
        synchronizePosition(sessionID: sessionID)
        engine.stop()
        activeSessionID = nil
        try? audioSession.deactivate()
        phase = .failed(failure)
    }

    private func navigateQueue(
        direction: PlaybackQueueDirection,
        isNaturalEnd: Bool
    ) async {
        guard let queue else {
            return
        }
        let candidates = queue.candidateIDs(
            for: direction,
            isNaturalEnd: isNaturalEnd
        )
        guard !candidates.isEmpty else {
            return
        }

        let generation = UUID()
        selectionGeneration = generation
        failedQueueNavigation = nil
        if phase == .playing,
           let activeSessionID {
            synchronizePosition(sessionID: activeSessionID)
        }
        stopActivePlayback()
        phase = .preparing

        defer {
            if selectionGeneration == generation {
                pendingSelectionID = nil
            }
        }

        for candidateID in candidates {
            guard selectionGeneration == generation else {
                return
            }
            guard !blockedSelectionIDs.contains(candidateID) else {
                continue
            }
            pendingSelectionID = candidateID

            let resolvedItem: PlaybackItem?
            do {
                resolvedItem = try await itemProvider.item(for: candidateID)
            } catch {
                resolvedItem = nil
            }

            guard selectionGeneration == generation else {
                return
            }
            guard let resolvedItem else {
                self.queue?.remove(id: candidateID)
                continue
            }
            guard case let .available(audioURL) = resolvedItem.availability else {
                continue
            }

            let preparation: AudioPlaybackPreparation
            do {
                preparation = try engine.prepare(url: audioURL)
            } catch {
                engine.stop()
                continue
            }
            guard preparation.duration.isFinite,
                  preparation.duration > 0 else {
                engine.stop()
                continue
            }

            self.queue?.commitNavigation(
                to: candidateID,
                direction: direction
            )
            currentItem = resolvedItem
            queueItems[resolvedItem.id] = resolvedItem
            activeSessionID = preparation.sessionID
            duration = preparation.duration
            position = 0
            startPreparedPlayback()
            return
        }

        guard selectionGeneration == generation else {
            return
        }
        failedQueueNavigation = FailedQueueNavigation(
            direction: direction,
            isNaturalEnd: isNaturalEnd
        )
        phase = .failed(.queueUnavailable)
    }
}

nonisolated private struct FailedQueueNavigation: Sendable {
    let direction: PlaybackQueueDirection
    let isNaturalEnd: Bool
}

nonisolated private final class PlaybackEventTasks: @unchecked Sendable {
    private let lock = NSLock()
    private var tasks: [Task<Void, Never>] = []

    // The lock makes storage and deinit cancellation safe across isolation.
    func store(_ task: Task<Void, Never>) {
        lock.withLock {
            tasks.append(task)
        }
    }

    func cancelAll() {
        let storedTasks = lock.withLock {
            let tasksToCancel = self.tasks
            self.tasks.removeAll()
            return tasksToCancel
        }
        for task in storedTasks {
            task.cancel()
        }
    }
}
