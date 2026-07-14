import SwiftUI
import UIKit

struct SongRow: View {
    let song: LibrarySong
    var isRemovalInProgress = false

    var body: some View {
        HStack(spacing: 12) {
            SongArtwork(url: song.artworkURL)

            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.headline)
                    .lineLimit(2)

                Text(song.artist ?? String(localized: "Unknown Artist"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if case .unavailable = song.availability {
                    Label("Unavailable", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("song.unavailable")
                }
            }

            Spacer(minLength: 8)

            if isRemovalInProgress {
                ProgressView()
                    .accessibilityLabel("Removing \(song.title)")
            } else if let duration = song.durationSeconds {
                Text(durationText(duration))
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(
                        Text("Duration: \(durationText(duration))")
                    )
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func durationText(_ duration: Double) -> String {
        let totalSeconds = max(0, Int(duration.rounded()))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct SongArtwork: View {
    let url: URL?
    var dimension: CGFloat = 56
    var cornerRadius: CGFloat = 8
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "music.note")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.quaternary)
            }
        }
        .frame(width: dimension, height: dimension)
        .clipShape(.rect(cornerRadius: cornerRadius))
        .accessibilityHidden(true)
        .task(id: url) {
            image = nil
            guard let url,
                  let data = await SongArtworkDataLoader.shared.load(at: url),
                  !Task.isCancelled else {
                return
            }
            image = UIImage(data: data)
        }
    }
}

private actor SongArtworkDataLoader {
    static let shared = SongArtworkDataLoader()

    func load(at url: URL) -> Data? {
        try? Data(contentsOf: url, options: .mappedIfSafe)
    }
}

#Preview("Available Song") {
    List {
        SongRow(
            song: LibrarySong(
                id: UUID(),
                title: "Aerial Lines",
                artist: "Mira Chen",
                album: "Night Transit",
                durationSeconds: 213,
                artworkURL: nil,
                availability: .available(
                    audioURL: URL(filePath: "/preview/aerial-lines.m4a")
                )
            )
        )
    }
}

#Preview("Unavailable Song") {
    List {
        SongRow(
            song: LibrarySong(
                id: UUID(),
                title: "Missing Resource",
                artist: nil,
                album: nil,
                durationSeconds: nil,
                artworkURL: nil,
                availability: .unavailable
            )
        )
    }
}
