import Foundation

nonisolated enum AudioSessionEvent: Equatable, Sendable {
    case interruptionBegan
}

protocol AudioSessionControlling: AnyObject {
    var events: AsyncStream<AudioSessionEvent> { get }

    func activate() throws
    func deactivate() throws
}
