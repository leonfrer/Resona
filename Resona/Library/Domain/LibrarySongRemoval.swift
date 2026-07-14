import Foundation

nonisolated struct LibrarySongRemoval: Equatable, Identifiable, Sendable {
    let id: UUID
    let title: String
    let managedAudioFilename: String
    let managedArtworkFilename: String?
}

nonisolated enum LibraryRemovalBeginning: Equatable, Sendable {
    case accepted(LibrarySongRemoval)
    case missing
}
