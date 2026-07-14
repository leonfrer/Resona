import Foundation

nonisolated struct LibraryPlaybackItemProvider: PlaybackItemProviding {
    private let repository: any LibraryRepository

    init(repository: any LibraryRepository) {
        self.repository = repository
    }

    func item(for songID: UUID) async throws -> PlaybackItem? {
        guard let song = try await repository.song(id: songID) else {
            return nil
        }

        return PlaybackItem(
            id: song.id,
            title: song.title,
            artist: song.artist,
            album: song.album,
            artworkURL: song.artworkURL,
            availability: song.availability,
            libraryDurationSeconds: song.durationSeconds
        )
    }

    func items(for songIDs: [UUID]) async throws -> [PlaybackItem] {
        let songs = try await repository.fetchSongs(locale: .autoupdatingCurrent)
        let songsByID = Dictionary(uniqueKeysWithValues: songs.map { ($0.id, $0) })
        return songIDs.compactMap { songID in
            songsByID[songID].map { PlaybackItem(librarySong: $0) }
        }
    }
}

private extension PlaybackItem {
    nonisolated init(librarySong: LibrarySong) {
        self.init(
            id: librarySong.id,
            title: librarySong.title,
            artist: librarySong.artist,
            album: librarySong.album,
            artworkURL: librarySong.artworkURL,
            availability: librarySong.availability,
            libraryDurationSeconds: librarySong.durationSeconds
        )
    }
}
