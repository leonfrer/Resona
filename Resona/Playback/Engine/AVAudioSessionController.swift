import AVFAudio
import Foundation

final class AVAudioSessionController: NSObject, AudioSessionControlling {
    let events: AsyncStream<AudioSessionEvent>

    private let session: AVAudioSession
    private let notificationCenter: NotificationCenter
    private let eventContinuation: AsyncStream<AudioSessionEvent>.Continuation

    init(
        session: AVAudioSession = .sharedInstance(),
        notificationCenter: NotificationCenter = .default
    ) throws {
        let (events, continuation) = AsyncStream<AudioSessionEvent>.makeStream()
        self.events = events
        eventContinuation = continuation
        self.session = session
        self.notificationCenter = notificationCenter
        super.init()

        try session.setCategory(.playback, mode: .default, options: [])
        notificationCenter.addObserver(
            self,
            selector: #selector(handleInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: session
        )
        notificationCenter.addObserver(
            self,
            selector: #selector(handleRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: session
        )
    }

    deinit {
        notificationCenter.removeObserver(self)
        eventContinuation.finish()
    }

    func activate() throws {
        try session.setActive(true)
    }

    func deactivate() throws {
        try session.setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }

    @objc private func handleInterruption(_ notification: Notification) {
        guard let event = AudioSessionNotificationMapper.interruptionEvent(
            userInfo: notification.userInfo
        ) else {
            return
        }
        eventContinuation.yield(event)
    }

    @objc private func handleRouteChange(_ notification: Notification) {
        guard let event = AudioSessionNotificationMapper.routeChangeEvent(
            userInfo: notification.userInfo
        ) else {
            return
        }
        eventContinuation.yield(event)
    }
}

nonisolated enum AudioSessionNotificationMapper {
    static func interruptionEvent(
        userInfo: [AnyHashable: Any]?
    ) -> AudioSessionEvent? {
        guard let rawType = uintValue(
            userInfo?[AVAudioSessionInterruptionTypeKey]
        ),
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else {
            return nil
        }
        switch type {
        case .began:
            return .interruptionBegan
        case .ended:
            let rawOptions = uintValue(
                userInfo?[AVAudioSessionInterruptionOptionKey]
            ) ?? 0
            let options = AVAudioSession.InterruptionOptions(
                rawValue: rawOptions
            )
            return .interruptionEnded(
                shouldResume: options.contains(.shouldResume)
            )
        @unknown default:
            return nil
        }
    }

    static func routeChangeEvent(
        userInfo: [AnyHashable: Any]?
    ) -> AudioSessionEvent? {
        guard let rawReason = uintValue(
            userInfo?[AVAudioSessionRouteChangeReasonKey]
        ),
              AVAudioSession.RouteChangeReason(rawValue: rawReason)
                == .oldDeviceUnavailable,
              let previousRoute = userInfo?[
                AVAudioSessionRouteChangePreviousRouteKey
              ] as? AVAudioSessionRouteDescription else {
            return nil
        }
        return routeChangeEvent(
            reason: .oldDeviceUnavailable,
            previousOutputPortTypes: previousRoute.outputs.map(\.portType)
        )
    }

    static func routeChangeEvent(
        reason: AVAudioSession.RouteChangeReason,
        previousOutputPortTypes: [AVAudioSession.Port]
    ) -> AudioSessionEvent? {
        guard reason == .oldDeviceUnavailable,
              previousOutputPortTypes.contains(where: isExternalOutput) else {
            return nil
        }
        return .externalOutputDisconnected
    }

    private static func isExternalOutput(_ portType: AVAudioSession.Port) -> Bool {
        portType != .builtInSpeaker && portType.rawValue != "Receiver"
    }

    private static func uintValue(_ value: Any?) -> UInt? {
        if let value = value as? UInt {
            return value
        }
        return (value as? NSNumber)?.uintValue
    }
}
