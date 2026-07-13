import Foundation
import Testing
@testable import Resona

@MainActor
struct SwiftDataLibraryRepositoryTests {
    @Test func roundTripsSongAndDerivesResourceAvailability() async throws {
        let container = try ResonaModelContainer.make(isStoredInMemoryOnly: true)
        let audioURL = URL(fileURLWithPath: "/tmp/managed/song.m4a")
        let artworkURL = URL(fileURLWithPath: "/tmp/managed/song.jpg")
        let resolver = StubLibraryResourceResolver(
            audioURLs: ["song.m4a": audioURL],
            artworkURLs: ["song.jpg": artworkURL]
        )
        let repository = SwiftDataLibraryRepository(
            modelContainer: container,
            resourceResolver: resolver
        )
        let id = UUID()

        try await repository.insert(
            draft(
                id: id,
                digest: "ABC123",
                audioFilename: "song.m4a",
                title: "Song",
                artworkFilename: "song.jpg"
            )
        )

        let songs = try await repository.fetchSongs(
            locale: Locale(identifier: "en_US")
        )

        #expect(
            songs == [
                LibrarySong(
                    id: id,
                    title: "Song",
                    artist: "Artist",
                    album: "Album",
                    durationSeconds: 123,
                    artworkURL: artworkURL,
                    availability: .available(audioURL: audioURL)
                ),
            ]
        )
    }

    @Test func reportsUnavailableWhenManagedAudioCannotBeResolved() async throws {
        let container = try ResonaModelContainer.make(isStoredInMemoryOnly: true)
        let repository = SwiftDataLibraryRepository(
            modelContainer: container,
            resourceResolver: StubLibraryResourceResolver()
        )
        let id = UUID()
        try await repository.insert(
            draft(
                id: id,
                digest: "missing",
                audioFilename: "missing.mp3",
                title: "Missing"
            )
        )

        let songs = try await repository.fetchSongs(
            locale: Locale(identifier: "en_US")
        )

        #expect(songs.count == 1)
        #expect(songs[0].id == id)
        #expect(songs[0].availability == .unavailable)
    }

    @Test func findsOnlyMatchingFingerprintCandidates() async throws {
        let container = try ResonaModelContainer.make(isStoredInMemoryOnly: true)
        let firstAudioURL = URL(fileURLWithPath: "/tmp/managed/first.wav")
        let repository = SwiftDataLibraryRepository(
            modelContainer: container,
            resourceResolver: StubLibraryResourceResolver(
                audioURLs: ["first.wav": firstAudioURL]
            )
        )
        let matchingID = UUID()
        try await repository.insert(
            draft(
                id: matchingID,
                digest: "AABBCC",
                byteCount: 42,
                audioFilename: "first.wav",
                title: "First"
            )
        )
        try await repository.insert(
            draft(
                id: UUID(),
                digest: "different",
                byteCount: 42,
                audioFilename: "second.wav",
                title: "Second"
            )
        )

        let candidates = try await repository.duplicateCandidates(
            matching: ContentFingerprint(digest: "aabbcc", byteCount: 42)
        )

        #expect(candidates.count == 1)
        #expect(candidates[0].id == matchingID)
        #expect(candidates[0].managedAudioURL == firstAudioURL)
    }

    @Test func restoresMetadataAndResourceWithoutChangingIdentity() async throws {
        let container = try ResonaModelContainer.make(isStoredInMemoryOnly: true)
        let restoredURL = URL(fileURLWithPath: "/tmp/managed/restored.aiff")
        let repository = SwiftDataLibraryRepository(
            modelContainer: container,
            resourceResolver: StubLibraryResourceResolver(
                audioURLs: ["restored.aiff": restoredURL]
            )
        )
        let id = UUID()
        try await repository.insert(
            draft(
                id: id,
                digest: "same-content",
                audioFilename: "missing.aiff",
                title: "Old Title"
            )
        )

        try await repository.restore(
            draft(
                id: id,
                digest: "same-content",
                audioFilename: "restored.aiff",
                title: "New Title"
            )
        )

        let songs = try await repository.fetchSongs(
            locale: Locale(identifier: "en_US")
        )
        #expect(songs.count == 1)
        #expect(songs[0].id == id)
        #expect(songs[0].title == "New Title")
        #expect(songs[0].availability == .available(audioURL: restoredURL))
    }

    @Test func rejectsDuplicateIdentityAndMissingRestoreTarget() async throws {
        let container = try ResonaModelContainer.make(isStoredInMemoryOnly: true)
        let repository = SwiftDataLibraryRepository(
            modelContainer: container,
            resourceResolver: StubLibraryResourceResolver()
        )
        let id = UUID()
        let original = draft(
            id: id,
            digest: "original",
            audioFilename: "original.mp3",
            title: "Original"
        )
        try await repository.insert(original)

        do {
            try await repository.insert(original)
            Issue.record("Expected a duplicate identity error")
        } catch let error as LibraryRepositoryError {
            #expect(error == .duplicateIdentity(id))
        }

        let missingID = UUID()
        do {
            try await repository.restore(
                draft(
                    id: missingID,
                    digest: "missing",
                    audioFilename: "missing.mp3",
                    title: "Missing"
                )
            )
            Issue.record("Expected a missing song error")
        } catch let error as LibraryRepositoryError {
            #expect(error == .missingSong(missingID))
        }
    }

    private func draft(
        id: UUID,
        digest: String,
        byteCount: Int64 = 128,
        audioFilename: String,
        title: String,
        artworkFilename: String? = nil
    ) -> LibrarySongDraft {
        LibrarySongDraft(
            id: id,
            fingerprint: ContentFingerprint(
                digest: digest,
                byteCount: byteCount
            ),
            managedAudioFilename: audioFilename,
            title: title,
            artist: "Artist",
            album: "Album",
            durationSeconds: 123,
            managedArtworkFilename: artworkFilename
        )
    }
}
