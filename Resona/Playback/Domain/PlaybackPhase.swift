nonisolated enum PlaybackPhase: Equatable, Sendable {
    case idle
    case preparing
    case playing
    case paused
    case stoppedAtEnd
    case failed(PlaybackFailure)
}
