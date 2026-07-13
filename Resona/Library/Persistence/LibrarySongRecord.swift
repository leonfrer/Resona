import Foundation
import SwiftData

@Model
final class LibrarySongRecord {
    @Attribute(.unique) var id: UUID
    var contentDigest: String
    var byteCount: Int64
    var managedAudioFilename: String
    var title: String
    var artist: String?
    var album: String?
    var durationSeconds: Double?
    var managedArtworkFilename: String?

    init(
        id: UUID,
        contentDigest: String,
        byteCount: Int64,
        managedAudioFilename: String,
        title: String,
        artist: String?,
        album: String?,
        durationSeconds: Double?,
        managedArtworkFilename: String?
    ) {
        self.id = id
        self.contentDigest = contentDigest
        self.byteCount = byteCount
        self.managedAudioFilename = managedAudioFilename
        self.title = title
        self.artist = artist
        self.album = album
        self.durationSeconds = durationSeconds
        self.managedArtworkFilename = managedArtworkFilename
    }
}
