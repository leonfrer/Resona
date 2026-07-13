import Foundation
import Testing
@testable import Resona

@MainActor
struct AVAudioPlayerEngineTests {
    @Test func preparesSupportedFixtureAndAcceptsSeeking() throws {
        let url = try AudioFixture.url("supported-aac", extension: "m4a")
        let engine = AVAudioPlayerEngine()

        let preparation = try engine.prepare(url: url)
        let target = preparation.duration / 2
        engine.seek(to: target, sessionID: preparation.sessionID)

        #expect(preparation.duration.isFinite)
        #expect(preparation.duration > 0)
        let observedPosition = try #require(
            engine.currentPosition(sessionID: preparation.sessionID)
        )
        #expect(abs(observedPosition - target) < 0.01)
        engine.stop()
        #expect(engine.currentPosition(sessionID: preparation.sessionID) == nil)
    }

    @Test func rejectsCorruptFixture() throws {
        let url = try AudioFixture.url("corrupt", extension: "mp3")
        let engine = AVAudioPlayerEngine()

        #expect(throws: AudioPlaybackEngineError.resourceInvalid) {
            try engine.prepare(url: url)
        }
    }
}
