import Foundation

@MainActor
protocol NowPlayingControlling: AnyObject {
    func update(_ state: PlaybackSystemState?)
}

@MainActor
final class NullNowPlayingController: NowPlayingControlling {
    func update(_ state: PlaybackSystemState?) {}
}
