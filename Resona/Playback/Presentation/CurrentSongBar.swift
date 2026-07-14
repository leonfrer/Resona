import SwiftUI

struct CurrentSongBar: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let item: PlaybackItem
    let phase: PlaybackPhase
    let artworkTransitionNamespace: Namespace.ID?
    let openPlayer: () -> Void
    let play: () -> Void
    let pause: () -> Void
    let previous: () -> Void
    let next: () -> Void
    let canGoPrevious: Bool
    let canGoNext: Bool
    let isTransitioning: Bool

    init(
        item: PlaybackItem,
        phase: PlaybackPhase,
        artworkTransitionNamespace: Namespace.ID? = nil,
        openPlayer: @escaping () -> Void,
        play: @escaping () -> Void,
        pause: @escaping () -> Void,
        previous: @escaping () -> Void,
        next: @escaping () -> Void,
        canGoPrevious: Bool,
        canGoNext: Bool,
        isTransitioning: Bool
    ) {
        self.item = item
        self.phase = phase
        self.artworkTransitionNamespace = artworkTransitionNamespace
        self.openPlayer = openPlayer
        self.play = play
        self.pause = pause
        self.previous = previous
        self.next = next
        self.canGoPrevious = canGoPrevious
        self.canGoNext = canGoNext
        self.isTransitioning = isTransitioning
    }

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))

        layout {
            Button(action: openPlayer) {
                HStack(spacing: 10) {
                    SongArtwork(
                        url: item.artworkURL,
                        dimension: 30,
                        cornerRadius: 6
                    )
                    .modifier(
                        CurrentSongArtworkTransitionSource(
                            namespace: artworkTransitionNamespace
                        )
                    )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.headline)
                            .lineLimit(1)
                        Text(item.artist ?? String(localized: "Unknown Artist"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open player for \(item.title)")
            .accessibilityHint(
                "Shows playback details without changing playback"
            )
            .accessibilityIdentifier("playback.currentSong.open")

            transportControls
                .frame(
                    maxWidth: dynamicTypeSize.isAccessibilitySize
                        ? .infinity
                        : nil,
                    alignment: .trailing
                )
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .padding(.vertical, 4)
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private var transportControls: some View {
        HStack(spacing: 2) {
            barTransportButton(
                label: "Previous",
                systemImage: "backward.fill",
                identifier: "playback.currentSong.previous",
                isEnabled: canGoPrevious,
                isInteractionEnabled: canGoPrevious && !isTransitioning,
                action: previous
            )

            barTransportButton(
                label: transportAction.label,
                systemImage: transportAction.systemImage,
                identifier: "playback.currentSong.transport",
                isEnabled: transportAction.isEnabled,
                isInteractionEnabled:
                    transportAction.isEnabled && !isTransitioning,
                action: transportAction.action
            )

            barTransportButton(
                label: "Next",
                systemImage: "forward.fill",
                identifier: "playback.currentSong.next",
                isEnabled: canGoNext,
                isInteractionEnabled: canGoNext && !isTransitioning,
                action: next
            )
        }
    }

    private func barTransportButton(
        label: LocalizedStringResource,
        systemImage: String,
        identifier: String,
        isEnabled: Bool,
        isInteractionEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.headline)
                .frame(width: 44, height: 44)
                .contentShape(.circle)
                .contentTransition(.symbolEffect(.replace))
                .animation(
                    reduceMotion ? nil : .snappy(duration: 0.24),
                    value: systemImage
                )
        }
        .buttonStyle(.plain)
        .disabled(!isInteractionEnabled)
        .opacity(isEnabled ? 1 : 0.3)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }

    private var transportAction: CurrentSongTransportAction {
        switch phase {
        case .playing:
            CurrentSongTransportAction(
                label: "Pause",
                systemImage: "pause.fill",
                isEnabled: true,
                action: pause
            )
        case .paused:
            CurrentSongTransportAction(
                label: "Play",
                systemImage: "play.fill",
                isEnabled: true,
                action: play
            )
        case .stoppedAtEnd:
            CurrentSongTransportAction(
                label: "Restart",
                systemImage: "arrow.counterclockwise",
                isEnabled: true,
                action: play
            )
        case .preparing:
            CurrentSongTransportAction(
                label: "Preparing",
                systemImage: "pause.fill",
                isEnabled: false,
                action: {}
            )
        case .idle, .failed:
            CurrentSongTransportAction(
                label: "Play",
                systemImage: "play.fill",
                isEnabled: false,
                action: {}
            )
        }
    }
}

enum PlaybackPresentationTransitionID: Hashable {
    case currentSongArtwork
}

private struct CurrentSongArtworkTransitionSource: ViewModifier {
    let namespace: Namespace.ID?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let namespace {
            content.matchedTransitionSource(
                id: PlaybackPresentationTransitionID.currentSongArtwork,
                in: namespace
            ) { source in
                source.clipShape(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                )
            }
        } else {
            content
        }
    }
}

private struct CurrentSongTransportAction {
    let label: LocalizedStringResource
    let systemImage: String
    let isEnabled: Bool
    let action: () -> Void
}

#if DEBUG
#Preview("Playing") {
    CurrentSongBar(
        item: .preview,
        phase: .playing,
        openPlayer: {},
        play: {},
        pause: {},
        previous: {},
        next: {},
        canGoPrevious: false,
        canGoNext: true,
        isTransitioning: false
    )
}

#Preview("Accessibility Text") {
    CurrentSongBar(
        item: .preview,
        phase: .paused,
        openPlayer: {},
        play: {},
        pause: {},
        previous: {},
        next: {},
        canGoPrevious: true,
        canGoNext: true,
        isTransitioning: false
    )
    .environment(\.dynamicTypeSize, .accessibility3)
}
#endif
