import AVFAudio
import Foundation

final class AVAudioPlayerEngine: AudioPlaybackEngine {
    let events: AsyncStream<AudioPlaybackEvent>

    private let eventContinuation: AsyncStream<AudioPlaybackEvent>.Continuation
    private var player: AVAudioPlayer?
    private var playerDelegate: AVAudioPlayerDelegateBridge?
    private var activeSessionID: UUID?
    private var positionTask: Task<Void, Never>?

    init() {
        let (events, continuation) = AsyncStream<AudioPlaybackEvent>.makeStream()
        self.events = events
        eventContinuation = continuation
    }

    func prepare(url: URL) throws -> AudioPlaybackPreparation {
        stop()

        let player: AVAudioPlayer
        do {
            player = try AVAudioPlayer(contentsOf: url)
        } catch {
            throw AudioPlaybackEngineError.resourceInvalid
        }

        let duration = player.duration
        guard duration.isFinite, duration > 0 else {
            throw AudioPlaybackEngineError.resourceInvalid
        }

        let sessionID = UUID()
        let playerDelegate = AVAudioPlayerDelegateBridge(
            sessionID: sessionID,
            eventHandler: { [weak self] event in
                self?.handleDelegateEvent(event)
            }
        )
        player.delegate = playerDelegate
        guard player.prepareToPlay() else {
            throw AudioPlaybackEngineError.resourceInvalid
        }

        self.player = player
        self.playerDelegate = playerDelegate
        activeSessionID = sessionID
        return AudioPlaybackPreparation(
            sessionID: sessionID,
            duration: duration
        )
    }

    func play(sessionID: UUID) throws {
        guard activeSessionID == sessionID,
              let player,
              player.play() else {
            throw AudioPlaybackEngineError.startupFailed
        }
        startPositionUpdates(sessionID: sessionID)
    }

    func pause(sessionID: UUID) {
        guard activeSessionID == sessionID else {
            return
        }
        player?.pause()
        stopPositionUpdates()
    }

    func seek(to seconds: TimeInterval, sessionID: UUID) {
        guard activeSessionID == sessionID else {
            return
        }
        player?.currentTime = seconds
    }

    func currentPosition(sessionID: UUID) -> TimeInterval? {
        guard activeSessionID == sessionID else {
            return nil
        }
        return player?.currentTime
    }

    func stop() {
        stopPositionUpdates()
        player?.stop()
        player = nil
        playerDelegate = nil
        activeSessionID = nil
    }

    private func startPositionUpdates(sessionID: UUID) {
        stopPositionUpdates()
        positionTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .milliseconds(250))
                } catch {
                    return
                }
                guard let self,
                      self.activeSessionID == sessionID,
                      let player = self.player,
                      player.isPlaying else {
                    return
                }
                self.eventContinuation.yield(
                    .position(
                        sessionID: sessionID,
                        seconds: player.currentTime
                    )
                )
            }
        }
    }

    private func stopPositionUpdates() {
        positionTask?.cancel()
        positionTask = nil
    }

    private func handleDelegateEvent(_ event: AudioPlaybackEvent) {
        switch event {
        case let .finished(sessionID),
             let .decodingFailed(sessionID),
             let .stoppedUnexpectedly(sessionID):
            guard sessionID == activeSessionID else {
                return
            }
            stopPositionUpdates()
        case .position:
            break
        }
        eventContinuation.yield(event)
    }
}

private final class AVAudioPlayerDelegateBridge: NSObject, AVAudioPlayerDelegate {
    private let sessionID: UUID
    private let eventHandler: (AudioPlaybackEvent) -> Void

    init(
        sessionID: UUID,
        eventHandler: @escaping (AudioPlaybackEvent) -> Void
    ) {
        self.sessionID = sessionID
        self.eventHandler = eventHandler
    }

    func audioPlayerDidFinishPlaying(
        _ player: AVAudioPlayer,
        successfully flag: Bool
    ) {
        eventHandler(
            flag
                ? .finished(sessionID: sessionID)
                : .stoppedUnexpectedly(sessionID: sessionID)
        )
    }

    func audioPlayerDecodeErrorDidOccur(
        _ player: AVAudioPlayer,
        error: (any Error)?
    ) {
        eventHandler(.decodingFailed(sessionID: sessionID))
    }
}
