import MediaPlayer
import UIKit

@MainActor
final class MPNowPlayingController: NowPlayingControlling {
    private let infoCenter: MPNowPlayingInfoCenter
    private var artworkTask: Task<Void, Never>?
    private var currentItemID: UUID?
    private var currentArtworkURL: URL?
    private var cachedArtwork: MPMediaItemArtwork?

    init(infoCenter: MPNowPlayingInfoCenter = .default()) {
        self.infoCenter = infoCenter
    }

    deinit {
        artworkTask?.cancel()
    }

    func update(_ state: PlaybackSystemState?) {
        guard let state else {
            artworkTask?.cancel()
            artworkTask = nil
            currentItemID = nil
            currentArtworkURL = nil
            cachedArtwork = nil
            infoCenter.nowPlayingInfo = nil
            return
        }

        let artworkIdentityChanged = currentItemID != state.item.id
            || currentArtworkURL != state.item.artworkURL
        if artworkIdentityChanged {
            artworkTask?.cancel()
            artworkTask = nil
            cachedArtwork = nil
            currentItemID = state.item.id
            currentArtworkURL = state.item.artworkURL
        }

        var info = Self.makeInfo(from: state)
        if let cachedArtwork {
            info[MPMediaItemPropertyArtwork] = cachedArtwork
        }
        infoCenter.nowPlayingInfo = info
        guard let artworkURL = state.item.artworkURL else {
            return
        }
        guard cachedArtwork == nil, artworkTask == nil else {
            return
        }

        let itemID = state.item.id
        artworkTask = Task { [weak self] in
            let data = await Task.detached(priority: .utility) {
                try? Data(contentsOf: artworkURL)
            }.value
            guard let self else {
                return
            }
            defer {
                if currentItemID == itemID,
                   currentArtworkURL == artworkURL {
                    artworkTask = nil
                }
            }
            guard !Task.isCancelled,
                  let data,
                  let image = UIImage(data: data),
                  currentItemID == itemID,
                  currentArtworkURL == artworkURL else {
                return
            }

            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in
                image
            }
            cachedArtwork = artwork
            var info = infoCenter.nowPlayingInfo ?? [:]
            info[MPMediaItemPropertyArtwork] = artwork
            infoCenter.nowPlayingInfo = info
        }
    }

    nonisolated static func makeInfo(
        from state: PlaybackSystemState
    ) -> [String: Any] {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: state.item.title,
            MPNowPlayingInfoPropertyExternalContentIdentifier:
                state.item.id.uuidString,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: state.elapsedTime,
            MPNowPlayingInfoPropertyPlaybackRate: state.playbackRate,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
        ]
        if let artist = state.item.artist {
            info[MPMediaItemPropertyArtist] = artist
        }
        if let album = state.item.album {
            info[MPMediaItemPropertyAlbumTitle] = album
        }
        if let duration = state.duration,
           duration.isFinite,
           duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        if let queueIndex = state.queueIndex {
            info[MPNowPlayingInfoPropertyPlaybackQueueIndex] = queueIndex
        }
        if let queueCount = state.queueCount {
            info[MPNowPlayingInfoPropertyPlaybackQueueCount] = queueCount
        }
        return info
    }
}
