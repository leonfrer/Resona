import SwiftUI

struct LibraryView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlaybackStore.self) private var playbackStore

    @State private var isSelectingFiles = false
    @State private var playerDestination: PlayerDestination?

    let initialImportSession: ImportSessionModel?

    init(initialImportSession: ImportSessionModel? = nil) {
        self.initialImportSession = initialImportSession
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
            List(songs) { song in
                switch song.availability {
                case .available:
                    Button {
                        Task {
                            await playbackStore.select(songID: song.id)
                        }
                    } label: {
                        SongRow(song: song)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .disabled(playbackStore.pendingSelectionID == song.id)
                    .accessibilityHint("Starts playback")
                    .accessibilityIdentifier(
                        "library.song.\(song.id.uuidString)"
                    )
                case .unavailable:
                    SongRow(song: song)
                        .accessibilityIdentifier(
                            "library.song.\(song.id.uuidString)"
                        )
                }
            }
            .listStyle(.plain)
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

}

private struct PlayerDestination: Identifiable {
    let songID: UUID

    var id: UUID {
        songID
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
