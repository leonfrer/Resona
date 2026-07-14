import Foundation
import Testing
@testable import Resona

@MainActor
struct LibraryPresentationTests {
    @Test func libraryLoadPreparesOnceAndPublishesSongs() async {
        let song = LibrarySong(
            id: UUID(),
            title: "Song",
            artist: nil,
            album: nil,
            durationSeconds: nil,
            artworkURL: nil,
            availability: .unavailable
        )
        let repository = PresentationTestRepository(songs: [song])
        let preparation = PreparationRecorder()
        let store = LibraryStore(
            repository: repository,
            prepareForInitialLoad: {
                try await preparation.prepare()
            }
        )

        await store.load()
        await store.load()

        #expect(store.state == .loaded([song]))
        #expect(await preparation.callCount == 1)
        #expect(await repository.fetchCount == 2)
    }

    @Test func failedInitialPreparationCanBeRetried() async {
        let repository = PresentationTestRepository(songs: [])
        let preparation = PreparationRecorder(failFirstCall: true)
        let store = LibraryStore(
            repository: repository,
            prepareForInitialLoad: {
                try await preparation.prepare()
            }
        )

        await store.load()
        #expect(store.state == .failed)

        await store.load()
        #expect(store.state == .loaded([]))
        #expect(await preparation.callCount == 2)
    }

    @Test func importSessionReducesMixedResultsAndRefreshesCommittedSongs() async {
        let urls = (0 ..< 6).map {
            URL(filePath: "/test/file-\($0).mp3")
        }
        let songID = UUID()
        let events: [ImportEvent] = [
            .progress(
                ImportProgress(
                    completedFileCount: 0,
                    totalFileCount: urls.count,
                    currentSourceDisplayName: urls[0].lastPathComponent
                )
            ),
            .result(result(urls[0], .imported(songID))),
            .result(result(urls[1], .restored(songID))),
            .result(result(urls[2], .alreadyImported(songID))),
            .result(
                result(
                    urls[3],
                    .warning(songID, [.metadataUnreadable])
                )
            ),
            .result(result(urls[4], .failed(.unsupportedCodec))),
            .result(result(urls[5], .cancelled)),
            .progress(
                ImportProgress(
                    completedFileCount: urls.count,
                    totalFileCount: urls.count,
                    currentSourceDisplayName: nil
                )
            ),
            .finished,
        ]
        let repository = PresentationTestRepository(songs: [])
        let store = LibraryStore(
            repository: repository,
            initialState: .loaded([])
        )
        let importer = PresentationTestAudioImporter(importEvents: events)
        let session = ImportSessionModel(
            sourceURLs: urls,
            audioImporter: importer,
            libraryStore: store
        )

        await session.start()

        #expect(session.phase == .finished)
        #expect(
            session.progress
                == ImportProgress(
                    completedFileCount: urls.count,
                    totalFileCount: urls.count,
                    currentSourceDisplayName: nil
                )
        )
        #expect(
            session.summary
                == ImportSummary(
                    importedCount: 2,
                    restoredCount: 1,
                    alreadyImportedCount: 1,
                    failedCount: 1,
                    cancelledCount: 1,
                    warningCount: 1
                )
        )
        #expect(await repository.fetchCount == 3)
        #expect(session.recoverySongID == songID)
    }

    @Test func retryReplacesOnlyTheAffectedFileResult() async {
        let firstURL = URL(filePath: "/test/first.mp3")
        let secondURL = URL(filePath: "/test/second.mp3")
        let songID = UUID()
        let importer = PresentationTestAudioImporter(
            importEvents: [
                .result(result(firstURL, .imported(songID))),
                .result(result(secondURL, .failed(.sourceAccessLost))),
                .finished,
            ],
            retryEvents: [
                .result(result(secondURL, .imported(songID))),
                .finished,
            ]
        )
        let repository = PresentationTestRepository(songs: [])
        let store = LibraryStore(
            repository: repository,
            initialState: .loaded([])
        )
        let session = ImportSessionModel(
            sourceURLs: [firstURL, secondURL],
            audioImporter: importer,
            libraryStore: store
        )

        await session.start()
        await session.retry(entryID: 1)

        #expect(session.entries.map(\.result?.outcome) == [.imported(songID), .imported(songID)])
        #expect(session.summary.importedCount == 2)
        #expect(session.summary.failedCount == 0)
        #expect(session.recoverySongID == songID)
        #expect(await importer.retriedURLs == [secondURL])
    }

    private func result(
        _ url: URL,
        _ outcome: ImportFileResult.Outcome
    ) -> ImportFileResult {
        ImportFileResult(
            sourceDisplayName: url.lastPathComponent,
            outcome: outcome
        )
    }
}

private actor PreparationRecorder {
    private(set) var callCount = 0
    private let failFirstCall: Bool

    init(failFirstCall: Bool = false) {
        self.failFirstCall = failFirstCall
    }

    func prepare() throws {
        callCount += 1
        if failFirstCall && callCount == 1 {
            throw PresentationTestError.preparationFailed
        }
    }
}

private actor PresentationTestRepository: LibraryRepository {
    let songs: [LibrarySong]
    private(set) var fetchCount = 0

    init(songs: [LibrarySong]) {
        self.songs = songs
    }

    func fetchSongs(locale: Locale) -> [LibrarySong] {
        fetchCount += 1
        return songs
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

private actor PresentationTestAudioImporter: AudioImporting {
    let importEvents: [ImportEvent]
    let retryEvents: [ImportEvent]
    private(set) var retriedURLs: [URL] = []

    init(
        importEvents: [ImportEvent],
        retryEvents: [ImportEvent] = []
    ) {
        self.importEvents = importEvents
        self.retryEvents = retryEvents
    }

    func importFiles(at sourceURLs: [URL]) -> AsyncStream<ImportEvent> {
        stream(for: importEvents)
    }

    func retryFile(at sourceURL: URL) -> AsyncStream<ImportEvent> {
        retriedURLs.append(sourceURL)
        return stream(for: retryEvents)
    }

    func cancelActiveImport() {}
    func reconcileLibrary() throws {}

    private func stream(for events: [ImportEvent]) -> AsyncStream<ImportEvent> {
        AsyncStream { continuation in
            for event in events {
                continuation.yield(event)
            }
            continuation.finish()
        }
    }
}

private enum PresentationTestError: Error {
    case preparationFailed
}
