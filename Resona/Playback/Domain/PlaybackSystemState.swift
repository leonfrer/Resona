import Foundation

nonisolated struct PlaybackSystemState: Equatable, Sendable {
    let item: PlaybackItem
    let duration: TimeInterval?
    let elapsedTime: TimeInterval
    let playbackRate: Double
    let queueIndex: Int?
    let queueCount: Int?
}

nonisolated struct PlaybackRemoteCapabilities: Equatable, Sendable {
    var canPlay = false
    var canPause = false
    var canTogglePlayPause = false
    var canGoNext = false
    var canGoPrevious = false
    var canChangePosition = false
}

nonisolated enum PlaybackRemoteCommand: Equatable, Sendable {
    case play
    case pause
    case togglePlayPause
    case next
    case previous
    case changePosition(TimeInterval)
}
