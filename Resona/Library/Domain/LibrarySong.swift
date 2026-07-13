import Foundation

nonisolated struct LibrarySong: Equatable, Identifiable, Sendable {
    let id: UUID
    let title: String
    let artist: String?
    let album: String?
    let durationSeconds: Double?
    let artworkURL: URL?
    let availability: SongAvailability
}
