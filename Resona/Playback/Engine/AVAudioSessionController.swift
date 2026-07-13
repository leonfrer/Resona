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
        guard let rawValue = notification.userInfo?[
            AVAudioSessionInterruptionTypeKey
        ] as? UInt,
              AVAudioSession.InterruptionType(rawValue: rawValue) == .began else {
            return
        }
        eventContinuation.yield(.interruptionBegan)
    }
}
