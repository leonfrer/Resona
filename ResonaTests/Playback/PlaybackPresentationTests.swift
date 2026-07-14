import Foundation
import Testing
@testable import Resona

struct PlaybackPresentationTests {
    @Test func formatsElapsedTimeDeterministically() {
        #expect(playbackTimeText(-1) == "0:00")
        #expect(playbackTimeText(65) == "1:05")
        #expect(playbackTimeText(3_661) == "1:01:01")
        #expect(playbackTimeText(.infinity) == "0:00")
    }

    @Test func mapsFailuresToTypedRecovery() {
        #expect(
            PlaybackFailure.resourceUnavailable.presentation.recoveryAction
                == .reimport
        )
        #expect(
            PlaybackFailure.resourceInvalid.presentation.recoveryAction
                == .reimport
        )
        #expect(
            PlaybackFailure.startupFailed.presentation.recoveryAction
                == .retry
        )
        #expect(
            PlaybackFailure.playbackFailed.presentation.recoveryAction
                == .retry
        )
        #expect(
            PlaybackFailure.queueUnavailable.presentation.recoveryAction
                == .retry
        )
    }
}
