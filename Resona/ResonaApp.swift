import SwiftData
import SwiftUI

@main
struct ResonaApp: App {
    private let sharedModelContainer: ModelContainer
    private let audioImporter: any AudioImporting
    private let initialImportSession: ImportSessionModel?
    @State private var libraryStore: LibraryStore

    init() {
        do {
            let dependencies = try AppDependencies.make()
            sharedModelContainer = dependencies.modelContainer
            audioImporter = dependencies.audioImporter
            initialImportSession = dependencies.initialImportSession
            _libraryStore = State(initialValue: dependencies.libraryStore)
        } catch {
            fatalError("Could not create app dependencies: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(initialImportSession: initialImportSession)
                .environment(libraryStore)
                .environment(\.audioImporter, audioImporter)
        }
        .modelContainer(sharedModelContainer)
    }
}

@MainActor
private struct AppDependencies {
    let modelContainer: ModelContainer
    let audioImporter: any AudioImporting
    let libraryStore: LibraryStore
    let initialImportSession: ImportSessionModel?

    static func make() throws -> AppDependencies {
#if DEBUG
        if let uiTestDependencies = try makeUITestDependencies() {
            return uiTestDependencies
        }
#endif
        let modelContainer = try ResonaModelContainer.make()
        let mediaStore = ManagedMediaStore(
            rootURL: try ManagedMediaStore.applicationSupportRoot()
        )
        let repository = SwiftDataLibraryRepository(
            modelContainer: modelContainer,
            resourceResolver: mediaStore
        )
        let audioImporter = AudioImportService(
            repository: repository,
            mediaStore: mediaStore
        )
        let libraryStore = LibraryStore(
            repository: repository,
            prepareForInitialLoad: {
                try await audioImporter.reconcileLibrary()
            }
        )

        return AppDependencies(
            modelContainer: modelContainer,
            audioImporter: audioImporter,
            libraryStore: libraryStore,
            initialImportSession: nil
        )
    }

#if DEBUG
    private static func makeUITestDependencies() throws -> AppDependencies? {
        let arguments = ProcessInfo.processInfo.arguments
        let scenario: UITestScenario
        if arguments.contains("--ui-testing-empty-library") {
            scenario = .emptyLibrary
        } else if arguments.contains("--ui-testing-populated-library") {
            scenario = .populatedLibrary
        } else if arguments.contains("--ui-testing-import-session") {
            scenario = .importSession
        } else {
            return nil
        }

        let modelContainer = try ResonaModelContainer.make(
            isStoredInMemoryOnly: true
        )
        let songs = scenario == .emptyLibrary ? [] : UITestScenario.songs
        let repository = UITestLibraryRepository(songs: songs)
        let libraryStore = LibraryStore(
            repository: repository,
            initialState: .loaded(songs)
        )
        let audioImporter: any AudioImporting
        let initialImportSession: ImportSessionModel?

        if scenario == .importSession {
            let importer = UITestImportAudioImporter()
            audioImporter = importer
            initialImportSession = ImportSessionModel(
                sourceURLs: UITestScenario.importURLs,
                audioImporter: importer,
                libraryStore: libraryStore
            )
        } else {
            audioImporter = UITestNoopAudioImporter()
            initialImportSession = nil
        }

        return AppDependencies(
            modelContainer: modelContainer,
            audioImporter: audioImporter,
            libraryStore: libraryStore,
            initialImportSession: initialImportSession
        )
    }
#endif
}

#if DEBUG
nonisolated private enum UITestScenario {
    case emptyLibrary
    case populatedLibrary
    case importSession

    static let importURLs = [
        URL(filePath: "/ui-test/Imported.m4a"),
        URL(filePath: "/ui-test/Warning.mp3"),
        URL(filePath: "/ui-test/Retry Me.wav"),
        URL(filePath: "/ui-test/Cancelled.aiff"),
    ]

    static let songs = [
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
                audioURL: URL(filePath: "/ui-test/aerial-lines.m4a")
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
                audioURL: URL(filePath: "/ui-test/fallback.mp3")
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

private actor UITestLibraryRepository: LibraryRepository {
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
    ) -> [LibraryDuplicateCandidate] { [] }

    func insert(_ draft: LibrarySongDraft) {}
    func restore(_ draft: LibrarySongDraft) {}
}

private actor UITestImportAudioImporter: AudioImporting {
    private var continuation: AsyncStream<ImportEvent>.Continuation?

    func importFiles(
        at sourceURLs: [URL]
    ) throws -> AsyncStream<ImportEvent> {
        let (stream, continuation) = AsyncStream<ImportEvent>.makeStream()
        self.continuation = continuation
        guard sourceURLs.count >= UITestScenario.importURLs.count else {
            continuation.yield(.finished)
            continuation.finish()
            self.continuation = nil
            return stream
        }
        let songID = UUID(
            uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 9)
        )
        continuation.yield(
            .progress(
                ImportProgress(
                    completedFileCount: 0,
                    totalFileCount: sourceURLs.count,
                    currentSourceDisplayName: sourceURLs.first?.lastPathComponent
                )
            )
        )
        continuation.yield(
            .result(
                ImportFileResult(
                    sourceDisplayName: sourceURLs[0].lastPathComponent,
                    outcome: .imported(songID)
                )
            )
        )
        continuation.yield(
            .result(
                ImportFileResult(
                    sourceDisplayName: sourceURLs[1].lastPathComponent,
                    outcome: .warning(songID, [.artworkUnreadable])
                )
            )
        )
        continuation.yield(
            .result(
                ImportFileResult(
                    sourceDisplayName: sourceURLs[2].lastPathComponent,
                    outcome: .failed(.sourceAccessLost)
                )
            )
        )
        continuation.yield(
            .progress(
                ImportProgress(
                    completedFileCount: 3,
                    totalFileCount: sourceURLs.count,
                    currentSourceDisplayName: sourceURLs[3].lastPathComponent
                )
            )
        )
        return stream
    }

    func retryFile(at sourceURL: URL) throws -> AsyncStream<ImportEvent> {
        let songID = UUID(
            uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10)
        )
        return AsyncStream { continuation in
            continuation.yield(
                .progress(
                    ImportProgress(
                        completedFileCount: 0,
                        totalFileCount: 1,
                        currentSourceDisplayName: sourceURL.lastPathComponent
                    )
                )
            )
            continuation.yield(
                .result(
                    ImportFileResult(
                        sourceDisplayName: sourceURL.lastPathComponent,
                        outcome: .imported(songID)
                    )
                )
            )
            continuation.yield(.finished)
            continuation.finish()
        }
    }

    func cancelActiveImport() {
        guard let continuation else {
            return
        }
        continuation.yield(
            .result(
                ImportFileResult(
                    sourceDisplayName: UITestScenario.importURLs[3].lastPathComponent,
                    outcome: .cancelled
                )
            )
        )
        continuation.yield(
            .progress(
                ImportProgress(
                    completedFileCount: UITestScenario.importURLs.count,
                    totalFileCount: UITestScenario.importURLs.count,
                    currentSourceDisplayName: nil
                )
            )
        )
        continuation.yield(.finished)
        continuation.finish()
        self.continuation = nil
    }

    func reconcileLibrary() throws {}
}

private struct UITestNoopAudioImporter: AudioImporting {
    func importFiles(
        at sourceURLs: [URL]
    ) async throws -> AsyncStream<ImportEvent> {
        AsyncStream { continuation in
            continuation.yield(.finished)
            continuation.finish()
        }
    }

    func retryFile(at sourceURL: URL) async throws -> AsyncStream<ImportEvent> {
        AsyncStream { continuation in
            continuation.yield(.finished)
            continuation.finish()
        }
    }

    func cancelActiveImport() async {}
    func reconcileLibrary() async throws {}
}
#endif
