import Foundation
import Testing
@testable import Resona

struct AudioMetadataNormalizerTests {
    @Test func embeddedTitleTakesPrecedenceAndOptionalTextIsTrimmed() {
        let normalized = AudioMetadataNormalizer().normalize(
            RawAudioMetadata(
                title: "  Embedded Title  ",
                artist: "  Artist  ",
                album: "\nAlbum\t"
            ),
            sourceDisplayName: "Filename.mp3"
        )

        #expect(normalized.title == "Embedded Title")
        #expect(normalized.artist == "Artist")
        #expect(normalized.album == "Album")
        #expect(normalized.warnings.isEmpty)
    }

    @Test func filenameThenUnknownTitleProvideFallbacks() {
        let normalizer = AudioMetadataNormalizer(unknownTitle: "Fallback Title")

        let filenameFallback = normalizer.normalize(
            RawAudioMetadata(title: " \n ", artist: " ", album: nil),
            sourceDisplayName: "  Filename Title .m4a"
        )
        let unknownFallback = normalizer.normalize(
            RawAudioMetadata(),
            sourceDisplayName: " .mp3"
        )

        #expect(filenameFallback.title == "Filename Title")
        #expect(filenameFallback.artist == nil)
        #expect(filenameFallback.album == nil)
        #expect(unknownFallback.title == "Fallback Title")
    }

    @Test func corruptArtworkBecomesAWarning() {
        let normalized = AudioMetadataNormalizer().normalize(
            RawAudioMetadata(artworkData: Data("not an image".utf8)),
            sourceDisplayName: "Song.wav"
        )

        #expect(normalized.title == "Song")
        #expect(normalized.artwork == nil)
        #expect(normalized.warnings == [.artworkUnreadable])
    }

    @Test func decodablePNGArtworkIsAccepted() throws {
        let data = try #require(
            Data(
                base64Encoded:
                    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
            )
        )

        let normalized = AudioMetadataNormalizer().normalize(
            RawAudioMetadata(artworkData: data),
            sourceDisplayName: "Song.wav"
        )

        #expect(normalized.artwork?.canonicalFileExtension == "png")
        #expect(normalized.artwork?.data == data)
        #expect(normalized.warnings.isEmpty)
    }
}
