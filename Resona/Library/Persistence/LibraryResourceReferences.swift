import Foundation

nonisolated struct LibraryResourceReferences: Equatable, Sendable {
    let audioFilenames: Set<String>
    let artworkFilenames: Set<String>

    init(
        audioFilenames: Set<String> = [],
        artworkFilenames: Set<String> = []
    ) {
        self.audioFilenames = audioFilenames
        self.artworkFilenames = artworkFilenames
    }
}
