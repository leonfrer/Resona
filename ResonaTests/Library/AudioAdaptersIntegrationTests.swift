import Foundation
import Testing
@testable import Resona

struct AudioAdaptersIntegrationTests {
    @Test(
        arguments: [
            ("supported", "mp3", "mp3"),
            ("supported-aac", "m4a", "m4a"),
            ("supported-alac", "m4a", "m4a"),
            ("supported", "wav", "wav"),
            ("supported", "aiff", "aiff"),
        ]
    )
    func acceptsSupportedContainerAndCodec(
        name: String,
        fileExtension: String,
        expectedCanonicalExtension: String
    ) async throws {
        let fixtureURL = try AudioFixture.url(name, extension: fileExtension)
        let stagingDirectory = FileManager.default.temporaryDirectory.appending(
            path: UUID().uuidString,
            directoryHint: .isDirectory
        )
        defer { try? FileManager.default.removeItem(at: stagingDirectory) }
        try FileManager.default.createDirectory(
            at: stagingDirectory,
            withIntermediateDirectories: true
        )
        let url = stagingDirectory.appending(path: "candidate.partial")
        try FileManager.default.copyItem(at: fixtureURL, to: url)

        let validated = try await AVFoundationAudioValidator()
            .validateAudio(at: url)

        #expect(
            validated.canonicalFileExtension == expectedCanonicalExtension
        )
        #expect(try #require(validated.durationSeconds) > 0)
    }

    @Test(
        arguments: [
            ("unsupported", "flac", AudioValidationError.unsupportedContainer),
            ("unsupported-codec", "wav", AudioValidationError.unsupportedCodec),
            ("video-only", "mp4", AudioValidationError.videoOnly),
            ("corrupt", "mp3", AudioValidationError.corruptAudio),
        ]
    )
    func rejectsInvalidMedia(
        name: String,
        fileExtension: String,
        expectedError: AudioValidationError
    ) async throws {
        let url = try AudioFixture.url(name, extension: fileExtension)

        do {
            _ = try await AVFoundationAudioValidator().validateAudio(at: url)
            Issue.record("Expected validation to reject \(name).\(fileExtension)")
        } catch let error as AudioValidationError {
            #expect(error == expectedError)
        }
    }

    @Test func readsCommonMetadataFromAValidatedAsset() async throws {
        let url = try AudioFixture.url("supported-aac", extension: "m4a")
        let validated = try await AVFoundationAudioValidator()
            .validateAudio(at: url)

        let metadata = try await AVFoundationAudioMetadataReader()
            .readMetadata(at: url, mimeType: validated.mimeType)

        #expect(metadata.title == "Fixture Title")
        #expect(metadata.artist == "Fixture Artist")
        #expect(metadata.album == "Fixture Album")
    }
}
