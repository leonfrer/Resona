import AVFoundation
import Foundation

actor AVFoundationAudioMetadataReader: AudioMetadataReading {
    func readMetadata(
        at url: URL,
        mimeType: String
    ) async throws -> RawAudioMetadata {
        let asset = AVURLAsset(
            url: url,
            options: [AVURLAssetOverrideMIMETypeKey: mimeType]
        )
        let items = try await asset.load(.commonMetadata)
        return RawAudioMetadata(
            title: await stringValue(
                for: .commonIdentifierTitle,
                in: items
            ),
            artist: await stringValue(
                for: .commonIdentifierArtist,
                in: items
            ),
            album: await stringValue(
                for: .commonIdentifierAlbumName,
                in: items
            ),
            artworkData: await dataValue(
                for: .commonIdentifierArtwork,
                in: items
            )
        )
    }

    private func stringValue(
        for identifier: AVMetadataIdentifier,
        in items: [AVMetadataItem]
    ) async -> String? {
        guard let item = AVMetadataItem.metadataItems(
            from: items,
            filteredByIdentifier: identifier
        ).first else {
            return nil
        }
        return try? await item.load(.stringValue)
    }

    private func dataValue(
        for identifier: AVMetadataIdentifier,
        in items: [AVMetadataItem]
    ) async -> Data? {
        guard let item = AVMetadataItem.metadataItems(
            from: items,
            filteredByIdentifier: identifier
        ).first else {
            return nil
        }
        return try? await item.load(.dataValue)
    }
}
