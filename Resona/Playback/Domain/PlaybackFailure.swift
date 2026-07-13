nonisolated enum PlaybackFailure: Equatable, Sendable {
    case resourceUnavailable
    case resourceInvalid
    case startupFailed
    case playbackFailed
}
