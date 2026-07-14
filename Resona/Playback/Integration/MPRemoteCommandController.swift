import Foundation
import MediaPlayer

@MainActor
final class MPRemoteCommandController: RemoteCommandControlling {
    private let commandCenter: MPRemoteCommandCenter
    private let availability = RemoteCommandAvailability()
    private var handler: (@MainActor (PlaybackRemoteCommand) -> Bool)?
    private var targets: [(MPRemoteCommand, Any)] = []

    init(commandCenter: MPRemoteCommandCenter = .shared()) {
        self.commandCenter = commandCenter
        disableUnsupportedCommands()
    }

    deinit {
        for (command, target) in targets {
            command.removeTarget(target)
        }
    }

    func install(
        handler: @escaping @MainActor (PlaybackRemoteCommand) -> Bool
    ) {
        guard self.handler == nil else {
            return
        }
        self.handler = handler
        register(commandCenter.playCommand, command: .play)
        register(commandCenter.pauseCommand, command: .pause)
        register(
            commandCenter.togglePlayPauseCommand,
            command: .togglePlayPause
        )
        register(commandCenter.nextTrackCommand, command: .next)
        register(commandCenter.previousTrackCommand, command: .previous)

        let positionTarget = commandCenter.changePlaybackPositionCommand
            .addTarget { [weak self] event in
                guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                    return .commandFailed
                }
                return self?.dispatch(.changePosition(event.positionTime))
                    ?? .commandFailed
            }
        targets.append((commandCenter.changePlaybackPositionCommand, positionTarget))
    }

    func update(capabilities: PlaybackRemoteCapabilities) {
        availability.update(capabilities)
        commandCenter.playCommand.isEnabled = capabilities.canPlay
        commandCenter.pauseCommand.isEnabled = capabilities.canPause
        commandCenter.togglePlayPauseCommand.isEnabled =
            capabilities.canTogglePlayPause
        commandCenter.nextTrackCommand.isEnabled = capabilities.canGoNext
        commandCenter.previousTrackCommand.isEnabled = capabilities.canGoPrevious
        commandCenter.changePlaybackPositionCommand.isEnabled =
            capabilities.canChangePosition
    }

    private func register(
        _ remoteCommand: MPRemoteCommand,
        command: PlaybackRemoteCommand
    ) {
        let target = remoteCommand.addTarget { [weak self] _ in
            self?.dispatch(command) ?? .commandFailed
        }
        targets.append((remoteCommand, target))
    }

    nonisolated private func dispatch(
        _ command: PlaybackRemoteCommand
    ) -> MPRemoteCommandHandlerStatus {
        guard availability.supports(command) else {
            return .noActionableNowPlayingItem
        }
        Task { @MainActor [weak self] in
            _ = self?.handler?(command)
        }
        return .success
    }

    private func disableUnsupportedCommands() {
        commandCenter.skipForwardCommand.isEnabled = false
        commandCenter.skipBackwardCommand.isEnabled = false
        commandCenter.changePlaybackRateCommand.isEnabled = false
        commandCenter.ratingCommand.isEnabled = false
        commandCenter.likeCommand.isEnabled = false
        commandCenter.dislikeCommand.isEnabled = false
        commandCenter.bookmarkCommand.isEnabled = false
        commandCenter.enableLanguageOptionCommand.isEnabled = false
        commandCenter.disableLanguageOptionCommand.isEnabled = false
    }
}

nonisolated private final class RemoteCommandAvailability: @unchecked Sendable {
    private let lock = NSLock()
    private var capabilities = PlaybackRemoteCapabilities()

    func update(_ capabilities: PlaybackRemoteCapabilities) {
        lock.lock()
        self.capabilities = capabilities
        lock.unlock()
    }

    func supports(_ command: PlaybackRemoteCommand) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return switch command {
        case .play:
            capabilities.canPlay
        case .pause:
            capabilities.canPause
        case .togglePlayPause:
            capabilities.canTogglePlayPause
        case .next:
            capabilities.canGoNext
        case .previous:
            capabilities.canGoPrevious
        case .changePosition:
            capabilities.canChangePosition
        }
    }
}
