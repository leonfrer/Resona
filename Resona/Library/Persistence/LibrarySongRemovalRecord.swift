import Foundation
import SwiftData

@Model
final class LibrarySongRemovalRecord {
    @Attribute(.unique) var id: UUID
    var title: String
    var managedAudioFilename: String
    var managedArtworkFilename: String?

    init(
        id: UUID,
        title: String,
        managedAudioFilename: String,
        managedArtworkFilename: String?
    ) {
        self.id = id
        self.title = title
        self.managedAudioFilename = managedAudioFilename
        self.managedArtworkFilename = managedArtworkFilename
    }
}
