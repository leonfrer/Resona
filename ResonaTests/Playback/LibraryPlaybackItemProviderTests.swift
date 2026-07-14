import Foundation
import Testing
@testable import Resona

struct LibraryPlaybackItemProviderTests {
    @Test func mapsCanonicalLibraryValuesAndAvailability() async throws {
        let id = UUID()
        let audioURL = URL(filePath: "/managed/song.m4a")
        let artworkURL = URL(filePath: "/managed/song.jpg")
        let song = LibrarySong(
            id: id,
            title: "Canonical Title",
            artist: "Artist",
            album: "Album",
            durationSeconds: 91,
            artworkURL: artworkURL,
            availability: .available(audioURL: audioURL)
        )
        let provider = LibraryPlaybackItemProvider(
            repository: PlaybackProviderTestRepository(songs: [song])
        )

        let item = try await provider.item(for: id)

        #expect(
            item
                == PlaybackItem(
                    id: id,
                    title: "Canonical Title",
                    artist: "Artist",
                    album: "Album",
                    artworkURL: artworkURL,
                    availability: .available(audioURL: audioURL),
                    libraryDurationSeconds: 91
                )
        )
    }

    @Test func preservesUnavailableAndMissingDistinction() async throws {
        let id = UUID()
        let song = LibrarySong(
            id: id,
            title: "Unavailable",
            artist: nil,
            album: nil,
            durationSeconds: nil,
            artworkURL: nil,
            availability: .unavailable
        )
        let provider = LibraryPlaybackItemProvider(
            repository: PlaybackProviderTestRepository(songs: [song])
        )

        #expect(try await provider.item(for: id)?.availability == .unavailable)
        #expect(try await provider.item(for: UUID()) == nil)
    }
}

private actor PlaybackProviderTestRepository: LibraryRepository {
    let songs: [LibrarySong]

    init(songs: [LibrarySong]) {
        self.songs = songs
    }

    func fetchSongs(locale: Locale) -> [LibrarySong] { songs }
    func resourceReferences() -> LibraryResourceReferences {
        LibraryResourceReferences()
    }
    func duplicateCandidates(
        matching fingerprint: ContentFingerprint
    ) -> [LibraryDuplicateCandidate] { [] }
    func insert(_ draft: LibrarySongDraft) {}
    func restore(_ draft: LibrarySongDraft) {}
    func beginRemoval(id: UUID) -> LibraryRemovalBeginning { .missing }
    func pendingRemovals() -> [LibrarySongRemoval] { [] }
    func finalizeRemoval(id: UUID) {}
}
