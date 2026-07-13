import Foundation

nonisolated protocol AudioMetadataReading: Sendable {
    func readMetadata(
        at url: URL,
        mimeType: String
    ) async throws -> RawAudioMetadata
}

nonisolated struct RawAudioMetadata: Equatable, Sendable {
    let title: String?
    let artist: String?
    let album: String?
    let artworkData: Data?

    init(
        title: String? = nil,
        artist: String? = nil,
        album: String? = nil,
        artworkData: Data? = nil
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.artworkData = artworkData
    }
}

nonisolated struct NormalizedAudioMetadata: Equatable, Sendable {
    let title: String
    let artist: String?
    let album: String?
    let artwork: ValidatedArtwork?
    let warnings: [ImportWarning]
}

nonisolated struct ValidatedArtwork: Equatable, Sendable {
    let data: Data
    let canonicalFileExtension: String
}
