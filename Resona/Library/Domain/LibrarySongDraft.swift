import Foundation

nonisolated struct LibrarySongDraft: Equatable, Sendable {
    let id: UUID
    let fingerprint: ContentFingerprint
    let managedAudioFilename: String
    let title: String
    let artist: String?
    let album: String?
    let durationSeconds: Double?
    let managedArtworkFilename: String?
}
