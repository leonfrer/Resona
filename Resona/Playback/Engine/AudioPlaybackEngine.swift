import Foundation

nonisolated struct AudioPlaybackPreparation: Equatable, Sendable {
    let sessionID: UUID
    let duration: TimeInterval
}

nonisolated enum AudioPlaybackEvent: Equatable, Sendable {
    case position(sessionID: UUID, seconds: TimeInterval)
    case finished(sessionID: UUID)
    case decodingFailed(sessionID: UUID)
    case stoppedUnexpectedly(sessionID: UUID)
}

nonisolated enum AudioPlaybackEngineError: Error, Equatable, Sendable {
    case resourceInvalid
    case startupFailed
}

protocol AudioPlaybackEngine: AnyObject {
    var events: AsyncStream<AudioPlaybackEvent> { get }

    func prepare(url: URL) throws -> AudioPlaybackPreparation
    func play(sessionID: UUID) throws
    func pause(sessionID: UUID)
    func seek(to seconds: TimeInterval, sessionID: UUID)
    func currentPosition(sessionID: UUID) -> TimeInterval?
    func stop()
}
