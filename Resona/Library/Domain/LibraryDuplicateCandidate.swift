import Foundation

nonisolated struct LibraryDuplicateCandidate: Equatable, Identifiable, Sendable {
    let id: UUID
    let fingerprint: ContentFingerprint
    let managedAudioFilename: String
    let managedAudioURL: URL?
}
