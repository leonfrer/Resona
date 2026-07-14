import Foundation

nonisolated enum PlaybackRecoveryAction: Equatable, Sendable {
    case retry
    case reimport
}

nonisolated struct PlaybackFailurePresentation: Equatable, Sendable {
    let title: LocalizedStringResource
    let message: LocalizedStringResource
    let recoveryLabel: LocalizedStringResource
    let recoveryAction: PlaybackRecoveryAction
}

extension PlaybackFailure {
    nonisolated var presentation: PlaybackFailurePresentation {
        switch self {
        case .resourceUnavailable:
            PlaybackFailurePresentation(
                title: "Song Unavailable",
                message: "Resona can’t find this song’s imported audio. Re-import the original file to restore it.",
                recoveryLabel: "Re-import",
                recoveryAction: .reimport
            )
        case .resourceInvalid:
            PlaybackFailurePresentation(
                title: "Song Can’t Be Played",
                message: "This imported audio can’t be opened or decoded. Re-import the original file to restore it.",
                recoveryLabel: "Re-import",
                recoveryAction: .reimport
            )
        case .startupFailed:
            PlaybackFailurePresentation(
                title: "Playback Couldn’t Start",
                message: "Resona couldn’t start audio playback. Try again.",
                recoveryLabel: "Try Again",
                recoveryAction: .retry
            )
        case .playbackFailed:
            PlaybackFailurePresentation(
                title: "Playback Stopped",
                message: "Audio playback stopped unexpectedly. Try again.",
                recoveryLabel: "Try Again",
                recoveryAction: .retry
            )
        case .queueUnavailable:
            PlaybackFailurePresentation(
                title: "No Playable Songs",
                message: "Resona couldn’t find another playable song in this queue. Re-import unavailable songs or choose another song.",
                recoveryLabel: "Try Again",
                recoveryAction: .retry
            )
        }
    }
}

extension PlaybackPhase {
    nonisolated var statusText: LocalizedStringResource {
        switch self {
        case .idle:
            "No Song"
        case .preparing:
            "Preparing"
        case .playing:
            "Playing"
        case .paused:
            "Paused"
        case .stoppedAtEnd:
            "Finished"
        case .failed:
            "Playback Error"
        }
    }

    nonisolated var statusSystemImage: String {
        switch self {
        case .idle:
            "music.note"
        case .preparing:
            "hourglass"
        case .playing:
            "speaker.wave.2.fill"
        case .paused:
            "pause.fill"
        case .stoppedAtEnd:
            "stop.fill"
        case .failed:
            "exclamationmark.triangle.fill"
        }
    }
}

nonisolated func playbackTimeText(_ seconds: TimeInterval) -> String {
    guard seconds.isFinite else {
        return "0:00"
    }
    let totalSeconds = max(0, Int(seconds.rounded()))
    let hours = totalSeconds / 3_600
    let minutes = (totalSeconds % 3_600) / 60
    let remainingSeconds = totalSeconds % 60
    if hours > 0 {
        return String(
            format: "%d:%02d:%02d",
            hours,
            minutes,
            remainingSeconds
        )
    }
    return String(format: "%d:%02d", minutes, remainingSeconds)
}
