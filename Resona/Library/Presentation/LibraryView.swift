import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(\.audioImporter) private var audioImporter

    @State private var isSelectingFiles = false
    @State private var importSession: ImportSessionModel?
    @State private var pickerFailure: FilePickerFailure?

    init(initialImportSession: ImportSessionModel? = nil) {
        _importSession = State(initialValue: initialImportSession)
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
            .fileImporter(
                isPresented: $isSelectingFiles,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: true
            ) { result in
                handleFileSelection(result)
            } onCancellation: {
                // Picker cancellation intentionally leaves the library unchanged.
            }
            .sheet(item: $importSession) { session in
                ImportSheet(session: session)
            }
            .alert(item: $pickerFailure) { failure in
                Alert(
                    title: Text("Files Couldn’t Be Opened"),
                    message: Text(failure.message),
                    dismissButton: .default(Text("OK"))
                )
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
            List(songs) { song in
                SongRow(song: song)
                    .accessibilityIdentifier("library.song.\(song.id.uuidString)")
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

    private func handleFileSelection(_ result: Result<[URL], any Error>) {
        switch result {
        case let .success(urls):
            guard !urls.isEmpty else {
                return
            }
            importSession = ImportSessionModel(
                sourceURLs: urls,
                audioImporter: audioImporter,
                libraryStore: libraryStore
            )
        case let .failure(error):
            pickerFailure = FilePickerFailure(error: error)
        }
    }
}

private struct FilePickerFailure: Identifiable {
    let id = UUID()
    let message: String

    init(error: any Error) {
        message = String(
            localized: "The selected files could not be accessed. Choose the files again."
        )
    }
}

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
