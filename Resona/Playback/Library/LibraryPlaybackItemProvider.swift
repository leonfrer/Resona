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
}
