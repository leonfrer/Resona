import Foundation
import ImageIO
import UniformTypeIdentifiers

nonisolated struct AudioMetadataNormalizer: Sendable {
    private let unknownTitle: String

    init(unknownTitle: String = "Unknown Title") {
        self.unknownTitle = unknownTitle
    }

    func normalize(
        _ metadata: RawAudioMetadata,
        sourceDisplayName: String
    ) -> NormalizedAudioMetadata {
        var warnings: [ImportWarning] = []
        let artwork: ValidatedArtwork?
        if let artworkData = metadata.artworkData {
            artwork = validateArtwork(artworkData)
            if artwork == nil {
                warnings.append(.artworkUnreadable)
            }
        } else {
            artwork = nil
        }

        return NormalizedAudioMetadata(
            title: normalizedText(metadata.title)
                ?? filenameTitle(sourceDisplayName)
                ?? unknownTitle,
            artist: normalizedText(metadata.artist),
            album: normalizedText(metadata.album),
            artwork: artwork,
            warnings: warnings
        )
    }

    private func normalizedText(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private func filenameTitle(_ sourceDisplayName: String) -> String? {
        let filename = URL(fileURLWithPath: sourceDisplayName)
            .deletingPathExtension()
            .lastPathComponent
        return normalizedText(filename)
    }

    private func validateArtwork(_ data: Data) -> ValidatedArtwork? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0,
              CGImageSourceCreateImageAtIndex(source, 0, nil) != nil,
              let typeIdentifier = CGImageSourceGetType(source),
              let type = UTType(typeIdentifier as String) else {
            return nil
        }

        let fileExtension: String?
        if type.conforms(to: .jpeg) {
            fileExtension = "jpg"
        } else if type.conforms(to: .png) {
            fileExtension = "png"
        } else if type.conforms(to: .heic) {
            fileExtension = "heic"
        } else {
            fileExtension = nil
        }
        guard let fileExtension else {
            return nil
        }
        return ValidatedArtwork(
            data: data,
            canonicalFileExtension: fileExtension
        )
    }
}
