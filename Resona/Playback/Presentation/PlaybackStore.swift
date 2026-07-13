import Foundation
import Observation

@MainActor
@Observable
final class PlaybackStore {
    private(set) var currentItem: PlaybackItem?
    private(set) var phase: PlaybackPhase
    private(set) var position: TimeInterval
    private(set) var duration: TimeInterval?
    private(set) var pendingSelectionID: UUID?

    private let itemProvider: any PlaybackItemProviding
    private let engine: any AudioPlaybackEngine
    private let audioSession: any AudioSessionControlling
    nonisolated private let eventTasks = PlaybackEventTasks()
    private var activeSessionID: UUID?
    private var selectionGeneration = UUID()

    init(
        itemProvider: any PlaybackItemProviding,
        engine: any AudioPlaybackEngine,
        audioSession: any AudioSessionControlling,
        initialItem: PlaybackItem? = nil,
        initialPhase: PlaybackPhase = .idle,
        initialPosition: TimeInterval = 0,
        initialDuration: TimeInterval? = nil
    ) {
        self.itemProvider = itemProvider
        self.engine = engine
        self.audioSession = audioSession
        currentItem = initialItem
        phase = initialPhase
        position = initialPosition
        duration = initialDuration

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

    func select(songID: UUID) async {
        guard pendingSelectionID != songID else {
            return
        }

        let generation = UUID()
        selectionGeneration = generation
        pendingSelectionID = songID
        stopActivePlayback()
        currentItem = nil
        position = 0
        duration = nil
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
            phase = .idle
            return
        }

        currentItem = resolvedItem
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
        guard case .failed = phase,
              let songID = currentItem?.id else {
            return
        }
        await select(songID: songID)
    }

    func synchronizePosition() {
        guard let sessionID = activeSessionID else {
            return
        }
        synchronizePosition(sessionID: sessionID)
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
            pause()
        }
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
