import SwiftData
import SwiftUI

@main
struct ResonaApp: App {
    private let sharedModelContainer: ModelContainer
    private let audioImporter: any AudioImporting
    private let libraryRemover: any LibraryRemoving
    private let initialImportSession: ImportSessionModel?
    @State private var libraryStore: LibraryStore
    @State private var playbackStore: PlaybackStore

    init() {
        do {
            let dependencies = try AppDependencies.make()
            sharedModelContainer = dependencies.modelContainer
            audioImporter = dependencies.audioImporter
            libraryRemover = dependencies.libraryRemover
            initialImportSession = dependencies.initialImportSession
            _libraryStore = State(initialValue: dependencies.libraryStore)
            _playbackStore = State(initialValue: dependencies.playbackStore)
        } catch {
            fatalError("Could not create app dependencies: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(initialImportSession: initialImportSession)
                .environment(libraryStore)
                .environment(playbackStore)
                .environment(\.audioImporter, audioImporter)
                .environment(\.libraryRemover, libraryRemover)
        }
        .modelContainer(sharedModelContainer)
    }
}

@MainActor
private struct AppDependencies {
    let modelContainer: ModelContainer
    let audioImporter: any AudioImporting
    let libraryRemover: any LibraryRemoving
    let libraryStore: LibraryStore
    let playbackStore: PlaybackStore
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
        let mutationGate = LibraryMutationGate()
        let removalService = LibraryRemovalService(
            repository: repository,
            mediaStore: mediaStore,
            mutationGate: mutationGate
        )
        let audioImporter = AudioImportService(
            repository: repository,
            mediaStore: mediaStore,
            mutationGate: mutationGate,
            removalReconciler: removalService
        )
        let libraryStore = LibraryStore(
            repository: repository,
            prepareForInitialLoad: {
                try await removalService.reconcileLibrary()
            }
        )
        let playbackStore = PlaybackStore(
            itemProvider: LibraryPlaybackItemProvider(repository: repository),
            engine: AVAudioPlayerEngine(),
            audioSession: try AVAudioSessionController()
        )

        return AppDependencies(
            modelContainer: modelContainer,
            audioImporter: audioImporter,
            libraryRemover: removalService,
            libraryStore: libraryStore,
            playbackStore: playbackStore,
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
        } else if arguments.contains("--ui-testing-playback-resource-failure") {
            scenario = .playbackResourceFailure
        } else if arguments.contains("--ui-testing-playback-transient-failure") {
            scenario = .playbackTransientFailure
        } else if arguments.contains("--ui-testing-removal-final-song") {
            scenario = .removalFinalSong
        } else if arguments.contains("--ui-testing-removal-cleanup-failure") {
            scenario = .removalCleanupFailure
        } else if arguments.contains("--ui-testing-removal-identifier-title") {
            scenario = .removalIdentifierTitle
        } else {
            return nil
        }

        let modelContainer = try ResonaModelContainer.make(
            isStoredInMemoryOnly: true
        )
        let songs: [LibrarySong]
        switch scenario {
        case .emptyLibrary:
            songs = []
        case .removalFinalSong, .removalCleanupFailure:
            songs = [UITestScenario.songs[0]]
        case .removalIdentifierTitle:
            songs = [UITestScenario.identifierTitleSong]
        default:
            songs = UITestScenario.songs
        }
        let repository = UITestLibraryRepository(songs: songs)
        let libraryStore = LibraryStore(repository: repository)
        let libraryRemover = UITestLibraryRemover(
            repository: repository,
            cleanupFailsFirstRemoval: scenario == .removalCleanupFailure
        )
        let playbackStore: PlaybackStore
        switch scenario {
        case .playbackResourceFailure:
            playbackStore = PlaybackStore(
                itemProvider: LibraryPlaybackItemProvider(repository: repository),
                engine: UITestAudioPlaybackEngine(),
                audioSession: UITestAudioSessionController(),
                initialItem: PlaybackItem(
                    librarySong: UITestScenario.songs[2]
                ),
                initialPhase: .failed(.resourceUnavailable)
            )
        case .playbackTransientFailure:
            playbackStore = PlaybackStore(
                itemProvider: LibraryPlaybackItemProvider(repository: repository),
                engine: UITestAudioPlaybackEngine(),
                audioSession: UITestAudioSessionController(),
                initialItem: PlaybackItem(
                    librarySong: UITestScenario.songs[0]
                ),
                initialPhase: .failed(.playbackFailed),
                initialPosition: 30,
                initialDuration: 213
            )
        case .emptyLibrary, .populatedLibrary, .importSession,
             .removalFinalSong, .removalCleanupFailure,
             .removalIdentifierTitle:
            playbackStore = PlaybackStore(
                itemProvider: LibraryPlaybackItemProvider(repository: repository),
                engine: UITestAudioPlaybackEngine(),
                audioSession: UITestAudioSessionController()
            )
        }
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
            libraryRemover: libraryRemover,
            libraryStore: libraryStore,
            playbackStore: playbackStore,
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
    case playbackResourceFailure
    case playbackTransientFailure
    case removalFinalSong
    case removalCleanupFailure
    case removalIdentifierTitle

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

    static let identifierTitleSong = LibrarySong(
        id: UUID(
            uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4)
        ),
        title: "00000000-0000-0000-0000-000000000004",
        artist: nil,
        album: nil,
        durationSeconds: 45,
        artworkURL: nil,
        availability: .available(
            audioURL: URL(filePath: "/ui-test/internal-title.m4a")
        )
    )
}

private actor UITestLibraryRepository: LibraryRepository {
    private var songs: [LibrarySong]

    init(songs: [LibrarySong]) {
        self.songs = songs
    }

    func fetchSongs(locale: Locale) -> [LibrarySong] {
        LibrarySongSorting.sorted(songs, locale: locale)
    }

    func removeSong(id: UUID) {
        songs.removeAll { $0.id == id }
    }

    func storedSong(id: UUID) -> LibrarySong? {
        songs.first { $0.id == id }
    }

    func resourceReferences() -> LibraryResourceReferences {
        LibraryResourceReferences()
    }

    func duplicateCandidates(
        matching fingerprint: ContentFingerprint
    ) -> [LibraryDuplicateCandidate] { [] }

    func insert(_ draft: LibrarySongDraft) {}
    func restore(_ draft: LibrarySongDraft) {}
    func beginRemoval(id: UUID) -> LibraryRemovalBeginning { .missing }
    func pendingRemovals() -> [LibrarySongRemoval] { [] }
    func finalizeRemoval(id: UUID) {}
}

private actor UITestLibraryRemover: LibraryRemoving {
    private let repository: UITestLibraryRepository
    private let cleanupFailsFirstRemoval: Bool
    private var didFailCleanup = false
    private var pendingIssues: [UUID: LibraryRemovalIssue] = [:]

    init(
        repository: UITestLibraryRepository,
        cleanupFailsFirstRemoval: Bool = false
    ) {
        self.repository = repository
        self.cleanupFailsFirstRemoval = cleanupFailsFirstRemoval
    }

    func remove(
        id: UUID,
        beforeRemoval: @Sendable () async throws -> Void,
        afterAcceptance: @Sendable () async -> Void
    ) async -> LibraryRemovalOutcome {
        do {
            try await beforeRemoval()
        } catch {
            return .notAccepted
        }
        guard let song = await repository.storedSong(id: id) else {
            return .missing
        }
        await repository.removeSong(id: id)
        await afterAcceptance()
        if cleanupFailsFirstRemoval, !didFailCleanup {
            didFailCleanup = true
            let issue = LibraryRemovalIssue(id: id, title: song.title)
            pendingIssues[id] = issue
            return .pendingCleanup(issue)
        }
        return .removed
    }

    func retryRemoval(id: UUID) -> LibraryRemovalRetryOutcome {
        guard pendingIssues.removeValue(forKey: id) != nil else {
            return .missing
        }
        return .completed
    }
}

private final class UITestAudioPlaybackEngine: AudioPlaybackEngine {
    let events = AsyncStream<AudioPlaybackEvent> { _ in }

    private var sessionID: UUID?
    private var position: TimeInterval = 0

    func prepare(url: URL) throws -> AudioPlaybackPreparation {
        let sessionID = UUID()
        let duration = url.lastPathComponent.contains("fallback") ? 65.0 : 213.0
        self.sessionID = sessionID
        position = 0
        return AudioPlaybackPreparation(
            sessionID: sessionID,
            duration: duration
        )
    }

    func play(sessionID: UUID) throws {
        guard self.sessionID == sessionID else {
            throw AudioPlaybackEngineError.startupFailed
        }
    }

    func pause(sessionID: UUID) {}

    func seek(to seconds: TimeInterval, sessionID: UUID) {
        guard self.sessionID == sessionID else {
            return
        }
        position = seconds
    }

    func currentPosition(sessionID: UUID) -> TimeInterval? {
        self.sessionID == sessionID ? position : nil
    }

    func stop() {
        sessionID = nil
        position = 0
    }
}

private final class UITestAudioSessionController: AudioSessionControlling {
    let events = AsyncStream<AudioSessionEvent> { _ in }

    func activate() throws {}
    func deactivate() throws {}
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

private extension PlaybackItem {
    init(librarySong: LibrarySong) {
        self.init(
            id: librarySong.id,
            title: librarySong.title,
            artist: librarySong.artist,
            album: librarySong.album,
            artworkURL: librarySong.artworkURL,
            availability: librarySong.availability,
            libraryDurationSeconds: librarySong.durationSeconds
        )
    }
}
