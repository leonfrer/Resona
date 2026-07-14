import Foundation

@MainActor
protocol RemoteCommandControlling: AnyObject {
    func install(
        handler: @escaping @MainActor (PlaybackRemoteCommand) -> Bool
    )
    func update(capabilities: PlaybackRemoteCapabilities)
}

@MainActor
final class NullRemoteCommandController: RemoteCommandControlling {
    func install(
        handler: @escaping @MainActor (PlaybackRemoteCommand) -> Bool
    ) {}

    func update(capabilities: PlaybackRemoteCapabilities) {}
}
