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

            primaryTransportControl

            if case let .failed(failure) = playbackStore.phase {
                failureView(failure)
            }
        }
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
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
                .frame(minWidth: 140)
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
