import SwiftUI

struct PlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(PlaybackStore.self) private var playbackStore
    @State private var isSelectingFiles = false
    @State private var presentedSheet: PlayerSheetDestination?
    @AccessibilityFocusState private var focusedControl: PlayerFocusedControl?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    ViewThatFits(in: .vertical) {
                        playerSurface(size: geometry.size)

                        ScrollView(showsIndicators: false) {
                            playerSurface(size: geometry.size)
                        }
                    }
                }
                .safeAreaPadding(.bottom, 12)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                Capsule()
                    .fill(.secondary)
                    .frame(width: 36, height: 5)
                    .padding(.bottom, 6)
                    .accessibilityHidden(true)
            }
            .modifier(
                PlayerDismissalInteraction(
                    size: geometry.size,
                    isEnabled: presentedSheet == nil,
                    reduceMotion: reduceMotion,
                    dismiss: {
                        dismiss()
                    }
                )
            )
            .accessibilityAction(.escape) {
                dismiss()
            }
        }
        .sheet(
            item: $presentedSheet,
            onDismiss: {
                focusedControl = .queue
            }
        ) { destination in
            switch destination {
            case .queue:
                PlayerQueueView()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
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
    }

    @ViewBuilder
    private func playerSurface(size: CGSize) -> some View {
        let artworkDimension = max(
            220,
            min(size.width - 32, size.height * 0.48, 380)
        )

        Group {
            if let item = playbackStore.currentItem {
                playerContent(
                    item: item,
                    artworkDimension: artworkDimension
                )
            } else {
                ContentUnavailableView(
                    "No Current Song",
                    systemImage: "music.note",
                    description: Text(
                        "Choose a song from your library to begin playback."
                    )
                )
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    private func playerContent(
        item: PlaybackItem,
        artworkDimension: CGFloat
    ) -> some View {
        VStack(spacing: 22) {
            SongArtwork(
                url: item.artworkURL,
                dimension: artworkDimension,
                cornerRadius: 18
            )
            .scaleEffect(playbackStore.phase == .playing ? 1.0 : 0.80)
            .animation(
                reduceMotion
                    ? nil
                    : playbackStore.phase == .playing
                        ? .spring(duration: 0.4, bounce: 0.55)
                        : .linear(duration: 0.2),
                value: playbackStore.phase == .playing
            )

            VStack(spacing: 5) {
                Text(item.title)
                    .font(.title2.bold())
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text(item.artist ?? String(localized: "Unknown Artist"))
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text(item.album ?? String(localized: "Unknown Album"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }

            progressControls

            transportControls

            if case let .failed(failure) = playbackStore.phase {
                failureView(failure)
            }

            queueButton
        }
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
    }

    private var transportControls: some View {
        HStack(spacing: 34) {
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
                .font(.system(size: 30, weight: .semibold))
                .frame(width: 52, height: 52)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.3)
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }

    @ViewBuilder
    private var progressControls: some View {
        if let duration = playbackStore.duration,
           duration.isFinite,
           duration > 0 {
            PlaybackScrubber(
                position: min(playbackStore.position, duration),
                duration: duration,
                isEnabled: playbackStore.canSeek,
                showsDisabledAppearance:
                    playbackStore.phase != .preparing,
                onSeek: playbackStore.seek
            )
            .accessibilityIdentifier("player.seek")
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
        if let primaryTransportAction {
            transportButton(
                label: primaryTransportAction.label,
                systemImage: primaryTransportAction.systemImage,
                isEnabled: primaryTransportAction.isEnabled,
                action: primaryTransportAction.action
            )
        }
    }

    private var primaryTransportAction: PlayerTransportAction? {
        switch playbackStore.phase {
        case .playing:
            PlayerTransportAction(
                label: "Pause",
                systemImage: "pause.fill",
                action: playbackStore.pause
            )
        case .paused:
            PlayerTransportAction(
                label: "Play",
                systemImage: "play.fill",
                action: playbackStore.play
            )
        case .stoppedAtEnd:
            PlayerTransportAction(
                label: "Restart",
                systemImage: "arrow.counterclockwise",
                action: playbackStore.play
            )
        case .preparing:
            PlayerTransportAction(
                label: "Preparing",
                systemImage: "pause.fill",
                isEnabled: false,
                action: {}
            )
        case .idle, .failed:
            nil
        }
    }

    private func transportButton(
        label: LocalizedStringResource,
        systemImage: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 46, weight: .semibold))
                .frame(width: 72, height: 72)
                .contentShape(.circle)
                .contentTransition(.symbolEffect(.replace))
                .animation(
                    reduceMotion ? nil : .snappy(duration: 0.24),
                    value: systemImage
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.3)
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
            .buttonStyle(.plain)
            .font(.headline)
            .foregroundStyle(.tint)
            .frame(minHeight: 44)
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

    private var queueButton: some View {
        Button {
            presentedSheet = .queue
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "list.bullet")
                Text("Queue")
                    .font(.headline)
                Spacer()
                Image(systemName: "chevron.up")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
            .frame(minHeight: 44)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(playbackStore.queue == nil)
        .accessibilityFocused($focusedControl, equals: .queue)
        .accessibilityIdentifier("player.queue.open")
    }
}

private enum PlayerSheetDestination: String, Identifiable {
    case queue

    var id: String { rawValue }
}

private enum PlayerFocusedControl: Hashable {
    case queue
}

private struct PlayerDismissalInteraction: ViewModifier {
    @State private var drag = PlayerDismissalDrag()

    let size: CGSize
    let isEnabled: Bool
    let reduceMotion: Bool
    let dismiss: () -> Void

    init(
        size: CGSize,
        isEnabled: Bool,
        reduceMotion: Bool,
        dismiss: @escaping () -> Void
    ) {
        self.size = size
        self.isEnabled = isEnabled
        self.reduceMotion = reduceMotion
        self.dismiss = dismiss
    }

    func body(content: Content) -> some View {
        content
            .offset(y: drag.offset)
            .simultaneousGesture(dismissalGesture)
    }

    private var dismissalGesture: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .global)
            .onChanged { value in
                guard isEnabled else {
                    return
                }

                if drag.intent == .undetermined {
                    drag.intent = PlayerDismissalIntent(
                        translation: value.translation
                    )
                }
                guard drag.intent == .vertical else {
                    return
                }
                drag.offset = max(0, value.translation.height)
            }
            .onEnded { value in
                guard isEnabled else {
                    resetDrag()
                    return
                }

                let translation = value.translation
                let predicted = value.predictedEndTranslation
                let shouldDismiss =
                    translation.height > max(120, size.height * 0.16)
                    || predicted.height > size.height * 0.32
                if drag.intent == .vertical && shouldDismiss {
                    dismiss()
                } else {
                    resetDrag()
                }
            }
    }

    private func resetDrag() {
        if reduceMotion {
            drag = PlayerDismissalDrag()
        } else {
            withAnimation(.smooth(duration: 0.22)) {
                drag = PlayerDismissalDrag()
            }
        }
    }
}

private struct PlayerDismissalDrag {
    var intent = PlayerDismissalIntent.undetermined
    var offset: CGFloat = 0
}

private enum PlayerDismissalIntent {
    case undetermined
    case vertical
    case rejected

    init(translation: CGSize) {
        self = translation.height > 0
            && translation.height > abs(translation.width)
            ? .vertical
            : .rejected
    }
}

private struct PlayerTransportAction {
    let label: LocalizedStringResource
    let systemImage: String
    var isEnabled = true
    let action: () -> Void
}

private struct PlaybackScrubber: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let position: TimeInterval
    let duration: TimeInterval
    let isEnabled: Bool
    let showsDisabledAppearance: Bool
    let onSeek: (TimeInterval) -> Void

    @State private var dragPosition: TimeInterval?
    @State private var dragStartPosition: TimeInterval?

    var body: some View {
        VStack(spacing: 2) {
            GeometryReader { geometry in
                let width = max(geometry.size.width, 1)
                let progress = min(max(displayPosition / duration, 0), 1)

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.tertiary)

                    Capsule()
                        .fill(.primary)
                        .frame(width: width * progress)
                }
                .frame(height: dragPosition == nil ? 4 : 10)
                .frame(maxHeight: .infinity)
                .contentShape(.rect)
                .animation(
                    reduceMotion ? nil : .snappy(duration: 0.16),
                    value: dragPosition != nil
                )
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            guard isEnabled else {
                                resetDrag()
                                return
                            }
                            let startPosition =
                                dragStartPosition ?? position
                            dragStartPosition = startPosition
                            dragPosition = position(
                                from: startPosition,
                                horizontalTranslation: value.translation.width,
                                width: width
                            )
                        }
                        .onEnded { value in
                            guard isEnabled else {
                                resetDrag()
                                return
                            }
                            defer { resetDrag() }
                            guard abs(value.translation.width) >= 6,
                                  abs(value.translation.width)
                                    > abs(value.translation.height),
                                  let dragStartPosition else {
                                return
                            }
                            let target = position(
                                from: dragStartPosition,
                                horizontalTranslation: value.translation.width,
                                width: width
                            )
                            onSeek(target)
                        }
                )
            }

            HStack {
                Text(playbackTimeText(displayPosition))
                Spacer()
                Text(playbackTimeText(duration))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .frame(height: 58)
        .opacity(isEnabled || !showsDisabledAppearance ? 1 : 0.35)
        .accessibilityElement()
        .accessibilityLabel("Playback Position")
        .accessibilityValue(playbackTimeText(displayPosition))
        .accessibilityAdjustableAction { direction in
            guard isEnabled else {
                return
            }
            let step = min(max(duration / 20, 5), 30)
            switch direction {
            case .increment:
                onSeek(min(position + step, duration))
            case .decrement:
                onSeek(max(position - step, 0))
            @unknown default:
                break
            }
        }
    }

    private var displayPosition: TimeInterval {
        dragPosition ?? position
    }

    private func position(
        from startPosition: TimeInterval,
        horizontalTranslation: CGFloat,
        width: CGFloat
    ) -> TimeInterval {
        let progressDelta = TimeInterval(horizontalTranslation / width)
        return min(max(startPosition + duration * progressDelta, 0), duration)
    }

    private func resetDrag() {
        dragPosition = nil
        dragStartPosition = nil
    }
}

private struct PlayerQueueView: View {
    @Environment(PlaybackStore.self) private var playbackStore

    var body: some View {
        let queuedItems = playbackStore.queuedItemsInTraversalOrder

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Queue")
                    .font(.title2.bold())

                queueModeControls

                if playbackStore.isLoadingQueueItems {
                    ProgressView("Loading Queue…")
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("player.queue.loading")
                }

                LazyVStack(spacing: 0) {
                    ForEach(Array(queuedItems.enumerated()), id: \.element.id) {
                        index, item in
                        PlayerQueueRow(
                            item: item,
                            isCurrent: item.id == playbackStore.currentItem?.id
                        )

                        if index < queuedItems.count - 1 {
                            Divider()
                                .padding(.leading, 48)
                        }
                    }
                }

                if !playbackStore.isLoadingQueueItems,
                   let queue = playbackStore.queue,
                   playbackStore.queueItems.count < queue.baseOrder.count {
                    Button("Reload Queue") {
                        Task {
                            await playbackStore.loadQueueItems()
                        }
                    }
                    .buttonStyle(.plain)
                    .font(.headline)
                    .foregroundStyle(.tint)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("player.queue.reload")
                }
            }
            .frame(maxWidth: 620, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .task(id: playbackStore.queue?.baseOrder) {
            await playbackStore.loadQueueItems()
        }
    }

    private var queueModeControls: some View {
        HStack(spacing: 36) {
            Button(action: playbackStore.toggleShuffle) {
                VStack(spacing: 6) {
                    Image(
                        systemName: playbackStore.queue?.isShuffleEnabled == true
                            ? "shuffle.circle.fill"
                            : "shuffle"
                    )
                    .font(.title2)
                    Text(
                        playbackStore.queue?.isShuffleEnabled == true
                            ? "Shuffle On"
                            : "Shuffle Off"
                    )
                    .font(.caption)
                }
                .frame(minWidth: 88, minHeight: 52)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("player.shuffle")

            Button(action: playbackStore.cycleRepeatMode) {
                VStack(spacing: 6) {
                    Image(
                        systemName: playbackStore.queue?.repeatMode.systemImage
                            ?? "repeat"
                    )
                    .font(.title2)
                    Text(
                        playbackStore.queue?.repeatMode.controlLabel
                            ?? "Repeat Off"
                    )
                    .font(.caption)
                }
                .frame(minWidth: 88, minHeight: 52)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("player.repeat")
        }
        .disabled(playbackStore.queue == nil)
        .frame(maxWidth: .infinity)
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

#Preview("No Current Song") {
    PlayerView()
        .playbackPreviewEnvironment(item: nil, phase: .idle)
}

#Preview("Dark Mode") {
    PlayerView()
        .playbackPreviewEnvironment(
            phase: .paused,
            position: 42,
            duration: 180
        )
        .preferredColorScheme(.dark)
}

#Preview("Accessibility Text") {
    PlayerView()
        .playbackPreviewEnvironment(
            phase: .paused,
            position: 42,
            duration: 180
        )
        .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Queue") {
    PlayerQueueView()
        .playbackPreviewEnvironment(
            phase: .paused,
            position: 42,
            duration: 180
        )
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
