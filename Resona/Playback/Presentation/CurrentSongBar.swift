import SwiftUI

struct CurrentSongBar: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let item: PlaybackItem
    let phase: PlaybackPhase
    let openPlayer: () -> Void
    let play: () -> Void
    let pause: () -> Void

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))

        layout {
            Button(action: openPlayer) {
                HStack(spacing: 12) {
                    SongArtwork(
                        url: item.artworkURL,
                        dimension: 52,
                        cornerRadius: 8
                    )
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title)
                            .font(.headline)
                            .lineLimit(2)
                        Text(item.artist ?? String(localized: "Unknown Artist"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        Label(phase.statusText, systemImage: phase.statusSystemImage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open player for \(item.title)")
            .accessibilityHint("Shows playback details without changing playback")
            .accessibilityIdentifier("playback.currentSong.open")

            if let transportAction {
                Button(action: transportAction.action) {
                    Label(transportAction.label, systemImage: transportAction.systemImage)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("playback.currentSong.transport")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private var transportAction: CurrentSongTransportAction? {
        switch phase {
        case .playing:
            CurrentSongTransportAction(
                label: "Pause",
                systemImage: "pause.fill",
                action: pause
            )
        case .paused:
            CurrentSongTransportAction(
                label: "Play",
                systemImage: "play.fill",
                action: play
            )
        case .stoppedAtEnd:
            CurrentSongTransportAction(
                label: "Restart",
                systemImage: "arrow.counterclockwise",
                action: play
            )
        case .idle, .preparing, .failed:
            nil
        }
    }
}

private struct CurrentSongTransportAction {
    let label: LocalizedStringResource
    let systemImage: String
    let action: () -> Void
}

#if DEBUG
#Preview("Playing") {
    CurrentSongBar(
        item: .preview,
        phase: .playing,
        openPlayer: {},
        play: {},
        pause: {}
    )
}

#Preview("Accessibility Text") {
    CurrentSongBar(
        item: .preview,
        phase: .paused,
        openPlayer: {},
        play: {},
        pause: {}
    )
    .environment(\.dynamicTypeSize, .accessibility3)
}
#endif
