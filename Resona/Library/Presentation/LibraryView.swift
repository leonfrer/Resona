import SwiftUI

struct LibraryView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlaybackStore.self) private var playbackStore
    @Environment(\.libraryRemover) private var libraryRemover

    @State private var isSelectingFiles = false
    @State private var playerDestination: PlayerDestination?
    @State private var removalCandidate: LibrarySong?

    let initialImportSession: ImportSessionModel?

    init(
        initialImportSession: ImportSessionModel? = nil,
        initialRemovalCandidate: LibrarySong? = nil
    ) {
        self.initialImportSession = initialImportSession
        _removalCandidate = State(initialValue: initialRemovalCandidate)
    }

    var body: some View {
        content
            .navigationTitle("Songs")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isSelectingFiles = true
                    } label: {
                        Label("Import Audio", systemImage: "plus")
                    }
                    .accessibilityIdentifier("library.import")
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let item = playbackStore.currentItem {
                    CurrentSongBar(
                        item: item,
                        phase: playbackStore.phase,
                        openPlayer: {
                            playerDestination = PlayerDestination(songID: item.id)
                        },
                        play: playbackStore.play,
                        pause: playbackStore.pause
                    )
                }
            }
            .sheet(item: $playerDestination) { _ in
                PlayerView()
            }
            .audioImportPresentation(
                isSelectingFiles: $isSelectingFiles,
                initialSession: initialImportSession
            )
            .alert(item: removalAlertBinding) { destination in
                removalAlert(destination)
            }
            .task {
                await libraryStore.load()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch libraryStore.state {
        case .idle, .loading:
            ProgressView("Loading Library…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("library.loading")
        case let .loaded(songs) where songs.isEmpty:
            ContentUnavailableView {
                Label("No Songs", systemImage: "music.note.list")
            } description: {
                Text(
                    "Choose audio files to copy them into Resona for offline listening."
                )
            } actions: {
                Button("Choose Files") {
                    isSelectingFiles = true
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("library.chooseFiles")
            }
        case let .loaded(songs):
            let visibleSongIDs = songs.map(\.id)
            List(songs) { song in
                songRow(song, visibleSongIDs: visibleSongIDs)
                    .transition(
                        .move(edge: .leading).combined(with: .opacity)
                    )
            }
            .listStyle(.plain)
            .animation(.snappy(duration: 0.28), value: songs.map(\.id))
        case .failed:
            ContentUnavailableView {
                Label("Library Unavailable", systemImage: "exclamationmark.triangle")
            } description: {
                Text("Resona couldn’t load your songs. Your imported files were not changed.")
            } actions: {
                Button("Try Again") {
                    Task {
                        await libraryStore.load()
                    }
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("library.retryLoad")
            }
        }
    }

    @ViewBuilder
    private func songRow(
        _ song: LibrarySong,
        visibleSongIDs: [UUID]
    ) -> some View {
        switch song.availability {
        case .available:
            Button {
                Task {
                    await playbackStore.select(
                        songID: song.id,
                        queueIDs: visibleSongIDs
                    )
                }
            } label: {
                SongRow(
                    song: song,
                    isRemovalInProgress: isRemoving(song)
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .disabled(
                playbackStore.pendingSelectionID == song.id || isRemoving(song)
            )
            .accessibilityHint("Starts playback")
            .accessibilityIdentifier("library.song.\(song.id.uuidString)")
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                removeButton(song)
            }
            .accessibilityAction(named: "Remove") {
                presentRemovalConfirmation(for: song)
            }
        case .unavailable:
            SongRow(
                song: song,
                isRemovalInProgress: isRemoving(song)
            )
            .accessibilityIdentifier("library.song.\(song.id.uuidString)")
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                removeButton(song)
                Button {
                    isSelectingFiles = true
                } label: {
                    Label("Re-import", systemImage: "arrow.clockwise")
                }
                .tint(.accentColor)
                .accessibilityIdentifier("library.reimport.\(song.id.uuidString)")
            }
            .accessibilityAction(named: "Re-import") {
                isSelectingFiles = true
            }
            .accessibilityAction(named: "Remove") {
                presentRemovalConfirmation(for: song)
            }
        }
    }

    private func removeButton(_ song: LibrarySong) -> some View {
        Button {
            presentRemovalConfirmation(for: song)
        } label: {
            Label("Remove", systemImage: "trash")
        }
        .tint(.red)
        .disabled(isRemoving(song))
        .accessibilityIdentifier("library.remove.\(song.id.uuidString)")
    }

    private func presentRemovalConfirmation(for song: LibrarySong) {
        guard !isRemoving(song) else {
            return
        }
        removalCandidate = song
    }

    private func isRemoving(_ song: LibrarySong) -> Bool {
        libraryStore.removalInProgressIDs.contains(song.id)
    }

    private var removalAlertBinding: Binding<LibraryRemovalAlert?> {
        Binding(
            get: {
                if let removalCandidate {
                    return .confirmation(removalCandidate)
                }
                return libraryStore.removalFeedback.map(
                    LibraryRemovalAlert.feedback
                )
            },
            set: { newValue in
                guard newValue == nil else {
                    return
                }
                if removalCandidate != nil {
                    removalCandidate = nil
                } else if let feedback = libraryStore.removalFeedback {
                    libraryStore.dismissRemovalFeedback(feedback)
                }
            }
        )
    }

    private func removalAlert(_ destination: LibraryRemovalAlert) -> Alert {
        switch destination {
        case let .confirmation(song):
            Alert(
                title: Text(
                    LibraryRemovalPresentation.confirmationTitle(
                        songTitle: song.title
                    )
                ),
                message: Text(
                    LibraryRemovalPresentation.confirmationMessage(
                        songTitle: song.title,
                        stopsPlayback: playbackStore.currentItem?.id == song.id
                    )
                ),
                primaryButton: .destructive(Text("Remove")) {
                    Task {
                        await libraryStore.remove(
                            song,
                            using: libraryRemover,
                            playbackInvalidator: playbackStore
                        )
                    }
                },
                secondaryButton: .cancel(Text("Cancel"))
            )
        case let .feedback(feedback):
            Alert(
                title: Text(
                    LibraryRemovalPresentation.feedbackTitle(feedback)
                ),
                message: Text(
                    LibraryRemovalPresentation.feedbackMessage(feedback)
                ),
                primaryButton: .default(Text("Try Again")) {
                    Task {
                        await libraryStore.retryRemovalFeedback(
                            feedback,
                            using: libraryRemover,
                            playbackInvalidator: playbackStore
                        )
                    }
                },
                secondaryButton: .cancel(Text("Dismiss"))
            )
        }
    }

}

private struct PlayerDestination: Identifiable {
    let songID: UUID

    var id: UUID {
        songID
    }
}

private enum LibraryRemovalAlert: Identifiable {
    enum ID: Hashable {
        case confirmation(UUID)
        case feedback(LibraryRemovalFeedback.ID)
    }

    case confirmation(LibrarySong)
    case feedback(LibraryRemovalFeedback)

    var id: ID {
        switch self {
        case let .confirmation(song):
            .confirmation(song.id)
        case let .feedback(feedback):
            .feedback(feedback.id)
        }
    }
}

#if DEBUG
#Preview("Empty Library") {
    NavigationStack {
        LibraryView()
    }
    .environment(
        LibraryStore(
            repository: PreviewLibraryRepository(songs: []),
            initialState: .loaded([])
        )
    )
    .environment(PlaybackStore.preview())
    .environment(\.libraryRemover, PreviewLibraryRemover())
}

#Preview("Populated Library") {
    let songs = LibrarySong.previewSongs
    NavigationStack {
        LibraryView()
    }
    .environment(
        LibraryStore(
            repository: PreviewLibraryRepository(songs: songs),
            initialState: .loaded(songs)
        )
    )
    .environment(PlaybackStore.preview())
    .environment(\.libraryRemover, PreviewLibraryRemover())
}

#Preview("Remove Non-Current Song") {
    let songs = LibrarySong.previewSongs
    NavigationStack {
        LibraryView(initialRemovalCandidate: songs[1])
    }
    .environment(
        LibraryStore(
            repository: PreviewLibraryRepository(songs: songs),
            initialState: .loaded(songs)
        )
    )
    .environment(PlaybackStore.preview())
    .environment(\.libraryRemover, PreviewLibraryRemover())
}

#Preview("Remove Current Song") {
    let songs = LibrarySong.previewSongs
    NavigationStack {
        LibraryView(initialRemovalCandidate: songs[0])
    }
    .environment(
        LibraryStore(
            repository: PreviewLibraryRepository(songs: songs),
            initialState: .loaded(songs)
        )
    )
    .environment(
        PlaybackStore.preview(
            item: .preview,
            phase: .playing,
            duration: 213
        )
    )
    .environment(\.libraryRemover, PreviewLibraryRemover())
}

#Preview("Removal In Progress") {
    let songs = LibrarySong.previewSongs
    NavigationStack {
        LibraryView()
    }
    .environment(
        LibraryStore(
            repository: PreviewLibraryRepository(songs: songs),
            initialState: .loaded(songs),
            initialRemovalInProgressIDs: [songs[0].id]
        )
    )
    .environment(PlaybackStore.preview())
    .environment(\.libraryRemover, PreviewLibraryRemover())
}

#Preview("Pending Cleanup Failure") {
    let songs = LibrarySong.previewSongs
    NavigationStack {
        LibraryView()
    }
    .environment(
        LibraryStore(
            repository: PreviewLibraryRepository(songs: songs),
            initialState: .loaded(songs),
            initialRemovalIssues: [
                LibraryRemovalIssue(
                    id: songs[0].id,
                    title: songs[0].title
                ),
            ]
        )
    )
    .environment(PlaybackStore.preview())
    .environment(\.libraryRemover, PreviewLibraryRemover())
}

private actor PreviewLibraryRepository: LibraryRepository {
    let songs: [LibrarySong]

    init(songs: [LibrarySong]) {
        self.songs = songs
    }

    func fetchSongs(locale: Locale) -> [LibrarySong] {
        LibrarySongSorting.sorted(songs, locale: locale)
    }

    func resourceReferences() -> LibraryResourceReferences {
        LibraryResourceReferences()
    }

    func duplicateCandidates(
        matching fingerprint: ContentFingerprint
    ) -> [LibraryDuplicateCandidate] {
        []
    }

    func insert(_ draft: LibrarySongDraft) {}

    func restore(_ draft: LibrarySongDraft) {}

    func beginRemoval(id: UUID) -> LibraryRemovalBeginning { .missing }

    func pendingRemovals() -> [LibrarySongRemoval] { [] }

    func finalizeRemoval(id: UUID) {}
}

private struct PreviewLibraryRemover: LibraryRemoving {
    func remove(
        id: UUID,
        beforeRemoval: @Sendable () async throws -> Void,
        afterAcceptance: @Sendable () async -> Void
    ) async -> LibraryRemovalOutcome {
        .notAccepted
    }

    func retryRemoval(id: UUID) async -> LibraryRemovalRetryOutcome {
        .failed
    }
}

private extension LibrarySong {
    static var previewSongs: [LibrarySong] {
        [
            LibrarySong(
                id: UUID(
                    uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)
                ),
                title: "Aerial Lines",
                artist: "Mira Chen",
                album: "Night Transit",
                durationSeconds: 213,
                artworkURL: nil,
                availability: .available(
                    audioURL: URL(filePath: "/preview/aerial-lines.m4a")
                )
            ),
            LibrarySong(
                id: UUID(
                    uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2)
                ),
                title: "Filename Fallback",
                artist: nil,
                album: nil,
                durationSeconds: 65,
                artworkURL: nil,
                availability: .available(
                    audioURL: URL(filePath: "/preview/fallback.mp3")
                )
            ),
            LibrarySong(
                id: UUID(
                    uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3)
                ),
                title: "Missing Resource",
                artist: "Unknown Signal",
                album: nil,
                durationSeconds: nil,
                artworkURL: nil,
                availability: .unavailable
            ),
        ]
    }
}
#endif
