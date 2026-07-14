import Foundation

nonisolated enum AudioSessionEvent: Equatable, Sendable {
    case interruptionBegan
    case interruptionEnded(shouldResume: Bool)
    case externalOutputDisconnected
}

protocol AudioSessionControlling: AnyObject {
    var events: AsyncStream<AudioSessionEvent> { get }

    func activate() throws
    func deactivate() throws
}
