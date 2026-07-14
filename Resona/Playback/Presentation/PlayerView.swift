import SwiftUI

struct PlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PlaybackStore.self) private var playbackStore
    @State private var isSelectingFiles = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if let item = playbackStore.currentItem {
                    playerContent(item: item)
                        .padding()
                } else {
                    ContentUnavailableView(
                        "No Current Song",
                        systemImage: "music.note",
                        description: Text("Choose a song from your library to begin playback.")
                    )
                    .padding()
                }
            }
            .navigationTitle("Now Playing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityIdentifier("player.done")
                }
            }
        }
        .audioImportPresentation(
            isSelectingFiles: $isSelectingFiles,
            onSessionDismiss: { songID in
                guard let songID else {
                    return
                }
                Task {
                    if playbackStore.currentItem?.id == songID {
                        await playbackStore.retry()
                    } else {
                        await playbackStore.select(songID: songID)
                    }
                }
            }
        )
        .task(id: playbackStore.queue?.baseOrder) {
            await playbackStore.loadQueueItems()
        }
        .accessibilityIdentifier("player.sheet")
    }

    private func playerContent(item: PlaybackItem) -> some View {
        VStack(spacing: 24) {
            SongArtwork(
                url: item.artworkURL,
                dimension: 260,
                cornerRadius: 20
            )

            VStack(spacing: 6) {
                Text(item.title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text(item.artist ?? String(localized: "Unknown Artist"))
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Text(item.album ?? String(localized: "Unknown Album"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Label(
                    playbackStore.phase.statusText,
                    systemImage: playbackStore.phase.statusSystemImage
                )
                .font(.subheadline)
                .padding(.top, 4)
            }

            progressControls

            queueModeControls

            transportControls

            if case let .failed(failure) = playbackStore.phase {
                failureView(failure)
            }

            queueSection
        }
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
    }

    private var queueModeControls: some View {
        HStack(spacing: 12) {
            Button(action: playbackStore.toggleShuffle) {
                Label(
                    playbackStore.queue?.isShuffleEnabled == true
                        ? "Shuffle On"
                        : "Shuffle Off",
                    systemImage: playbackStore.queue?.isShuffleEnabled == true
                        ? "shuffle.circle.fill"
                        : "shuffle"
                )
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("player.shuffle")

            Button(action: playbackStore.cycleRepeatMode) {
                Label(
                    playbackStore.queue?.repeatMode.controlLabel
                        ?? "Repeat Off",
                    systemImage: playbackStore.queue?.repeatMode.systemImage
                        ?? "repeat"
                )
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("player.repeat")
        }
        .disabled(playbackStore.queue == nil)
    }

    private var transportControls: some View {
        HStack(spacing: 28) {
            queueTransportButton(
                label: "Previous",
                systemImage: "backward.fill",
                identifier: "player.previous",
                isEnabled: playbackStore.canGoPrevious,
                action: playbackStore.previous
            )

            primaryTransportControl

            queueTransportButton(
                label: "Next",
                systemImage: "forward.fill",
                identifier: "player.next",
                isEnabled: playbackStore.canGoNext,
                action: playbackStore.next
            )
        }
    }

    private func queueTransportButton(
        label: LocalizedStringResource,
        systemImage: String,
        identifier: String,
        isEnabled: Bool,
        action: @escaping () async -> Void
    ) -> some View {
        Button {
            Task {
                await action()
            }
        } label: {
            Label(label, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .font(.title2.bold())
                .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .disabled(!isEnabled || playbackStore.pendingSelectionID != nil)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }

    @ViewBuilder
    private var progressControls: some View {
        if let duration = playbackStore.duration,
           duration.isFinite,
           duration > 0 {
            VStack(spacing: 8) {
                Slider(
                    value: Binding(
                        get: { min(playbackStore.position, duration) },
                        set: playbackStore.seek
                    ),
                    in: 0 ... duration
                )
                .disabled(!playbackStore.canSeek)
                .accessibilityLabel("Playback Position")
                .accessibilityIdentifier("player.seek")

                HStack {
                    Text(playbackTimeText(playbackStore.position))
                    Spacer()
                    Text(playbackTimeText(duration))
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }
        } else {
            VStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Playback position is available after the song is prepared.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Playback position unavailable")
        }
    }

    @ViewBuilder
    private var primaryTransportControl: some View {
        switch playbackStore.phase {
        case .playing:
            transportButton(
                label: "Pause",
                systemImage: "pause.fill",
                action: playbackStore.pause
            )
        case .paused:
            transportButton(
                label: "Play",
                systemImage: "play.fill",
                action: playbackStore.play
            )
        case .stoppedAtEnd:
            transportButton(
                label: "Restart",
                systemImage: "arrow.counterclockwise",
                action: playbackStore.play
            )
        case .preparing:
            ProgressView("Preparing…")
                .accessibilityIdentifier("player.preparing")
        case .idle, .failed:
            EmptyView()
        }
    }

    private func transportButton(
        label: LocalizedStringResource,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(label, systemImage: systemImage)
                .font(.title3.bold())
                .frame(minWidth: 120)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .accessibilityLabel(label)
        .accessibilityIdentifier("player.transport")
    }

    private func failureView(_ failure: PlaybackFailure) -> some View {
        let presentation = failure.presentation
        return VStack(spacing: 10) {
            Label(presentation.title, systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
            Text(presentation.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(presentation.recoveryLabel) {
                switch presentation.recoveryAction {
                case .retry:
                    Task {
                        await playbackStore.retry()
                    }
                case .reimport:
                    isSelectingFiles = true
                }
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier(
                presentation.recoveryAction == .retry
                    ? "player.retry"
                    : "player.reimport"
            )
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.quaternary, in: .rect(cornerRadius: 16))
    }

    @ViewBuilder
    private var queueSection: some View {
        if playbackStore.queue != nil {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Queue")
                        .font(.headline)
                    Spacer()
                    if playbackStore.isLoadingQueueItems {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityLabel("Loading queue")
                    }
                }

                LazyVStack(spacing: 0) {
                    ForEach(playbackStore.queuedItemsInTraversalOrder) { item in
                        PlayerQueueRow(
                            item: item,
                            isCurrent: item.id == playbackStore.currentItem?.id
                        )
                    }
                }
                .background(.quaternary, in: .rect(cornerRadius: 14))

                if !playbackStore.isLoadingQueueItems,
                   let queue = playbackStore.queue,
                   playbackStore.queueItems.count < queue.baseOrder.count {
                    Button("Reload Queue") {
                        Task {
                            await playbackStore.loadQueueItems()
                        }
                    }
                    .accessibilityIdentifier("player.queue.reload")
                }
            }
            .accessibilityIdentifier("player.queue")
        }
    }
}

private struct PlayerQueueRow: View {
    let item: PlaybackItem
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isCurrent ? "speaker.wave.2.fill" : "music.note")
                .foregroundStyle(isCurrent ? .primary : .secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.subheadline.weight(isCurrent ? .semibold : .regular))
                    .lineLimit(2)
                Text(item.artist ?? String(localized: "Unknown Artist"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if isCurrent {
                Text("Current")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if case .unavailable = item.availability {
                Label("Unavailable", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("player.queue.item.\(item.id.uuidString)")
    }
}

private extension PlaybackRepeatMode {
    var controlLabel: LocalizedStringResource {
        switch self {
        case .off:
            "Repeat Off"
        case .all:
            "Repeat All"
        case .one:
            "Repeat One"
        }
    }

    var systemImage: String {
        switch self {
        case .off, .all:
            "repeat"
        case .one:
            "repeat.1"
        }
    }
}

#if DEBUG
#Preview("Playing") {
    PlayerView()
        .playbackPreviewEnvironment(phase: .playing, position: 42, duration: 180)
}

#Preview("Stopped at End") {
    PlayerView()
        .playbackPreviewEnvironment(
            phase: .stoppedAtEnd,
            position: 180,
            duration: 180
        )
}

#Preview("Preparing") {
    PlayerView()
        .playbackPreviewEnvironment(phase: .preparing)
}

#Preview("Re-import Failure") {
    PlayerView()
        .playbackPreviewEnvironment(phase: .failed(.resourceUnavailable))
}

#Preview("Try Again Failure") {
    PlayerView()
        .playbackPreviewEnvironment(
            phase: .failed(.playbackFailed),
            position: 30,
            duration: 180
        )
}
#endif
