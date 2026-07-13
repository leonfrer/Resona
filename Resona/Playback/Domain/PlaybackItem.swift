import Foundation

nonisolated struct PlaybackItem: Equatable, Identifiable, Sendable {
    let id: UUID
    let title: String
    let artist: String?
    let album: String?
    let artworkURL: URL?
    let availability: SongAvailability
    let libraryDurationSeconds: Double?
}
