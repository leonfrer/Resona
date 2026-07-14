import AVFAudio
import MediaPlayer
import Testing
@testable import Resona

@MainActor
struct PlaybackSystemIntegrationTests {
    @Test func nowPlayingInfoMapsCanonicalMetadataAndQueueState() {
        let item = PlaybackItem(
            id: UUID(),
            title: "Canonical Title",
            artist: "Artist",
            album: "Album",
            artworkURL: nil,
            availability: .unavailable,
            libraryDurationSeconds: 120
        )
        let info = MPNowPlayingController.makeInfo(
            from: PlaybackSystemState(
                item: item,
                duration: 120,
                elapsedTime: 42,
                playbackRate: 0,
                queueIndex: 1,
                queueCount: 3
            )
        )

        #expect(info[MPMediaItemPropertyTitle] as? String == "Canonical Title")
        #expect(info[MPMediaItemPropertyArtist] as? String == "Artist")
        #expect(info[MPMediaItemPropertyAlbumTitle] as? String == "Album")
        #expect(info[MPMediaItemPropertyPlaybackDuration] as? Double == 120)
        #expect(info[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? Double == 42)
        #expect(info[MPNowPlayingInfoPropertyPlaybackRate] as? Double == 0)
        #expect(info[MPNowPlayingInfoPropertyPlaybackQueueIndex] as? Int == 1)
        #expect(info[MPNowPlayingInfoPropertyPlaybackQueueCount] as? Int == 3)
        #expect(
            info[MPNowPlayingInfoPropertyExternalContentIdentifier] as? String
                == item.id.uuidString
        )
    }

    @Test func interruptionNotificationsMapTypedResumeRecommendation() {
        #expect(
            AudioSessionNotificationMapper.interruptionEvent(
                userInfo: [
                    AVAudioSessionInterruptionTypeKey:
                        AVAudioSession.InterruptionType.began.rawValue,
                ]
            ) == .interruptionBegan
        )
        #expect(
            AudioSessionNotificationMapper.interruptionEvent(
                userInfo: [
                    AVAudioSessionInterruptionTypeKey:
                        AVAudioSession.InterruptionType.ended.rawValue,
                    AVAudioSessionInterruptionOptionKey:
                        AVAudioSession.InterruptionOptions.shouldResume.rawValue,
                ]
            ) == .interruptionEnded(shouldResume: true)
        )
        #expect(
            AudioSessionNotificationMapper.interruptionEvent(userInfo: [:])
                == nil
        )
    }

    @Test func routeMapperOnlyReportsExternalOutputDisconnection() {
        #expect(
            AudioSessionNotificationMapper.routeChangeEvent(
                reason: .oldDeviceUnavailable,
                previousOutputPortTypes: [.headphones]
            ) == .externalOutputDisconnected
        )
        #expect(
            AudioSessionNotificationMapper.routeChangeEvent(
                reason: .oldDeviceUnavailable,
                previousOutputPortTypes: [.builtInSpeaker]
            ) == nil
        )
        #expect(
            AudioSessionNotificationMapper.routeChangeEvent(
                reason: .newDeviceAvailable,
                previousOutputPortTypes: [.headphones]
            ) == nil
        )
    }
}
