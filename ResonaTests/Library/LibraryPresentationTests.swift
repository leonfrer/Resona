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
                return []
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
                return []
            }
        )

        await store.load()
        #expect(store.state == .failed)

        await store.load()
        #expect(store.state == .loaded([]))
        #expect(await preparation.callCount == 2)
    }

    @Test func initialCleanupIssuesArePresentedInStableIdentityOrder() async {
        let earlier = LibraryRemovalIssue(
            id: UUID(
                uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)
            ),
            title: "Earlier"
        )
        let later = LibraryRemovalIssue(
            id: UUID(
                uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2)
            ),
            title: "Later"
        )
        let store = LibraryStore(
            repository: PresentationTestRepository(songs: []),
            prepareForInitialLoad: { [later, earlier, later] }
        )

        await store.load()

        #expect(store.removalFeedback == .cleanupIssue(earlier))
        store.dismissRemovalFeedback(.cleanupIssue(earlier))
        #expect(store.removalFeedback == .cleanupIssue(later))
    }

    @Test func acceptedRemovalInvalidatesPlaybackAndRefreshesAuthoritativeState() async {
        let song = presentationSong(title: "Current")
        let repository = PresentationTestRepository(songs: [song])
        let remover = PresentationTestLibraryRemover(
            repository: repository,
            removeOutcomes: [.removed]
        )
        let playback = PresentationTestPlaybackInvalidator()
        let store = LibraryStore(
            repository: repository,
            initialState: .loaded([song])
        )

        await store.remove(
            song,
            using: remover,
            playbackInvalidator: playback
        )

        #expect(store.state == .loaded([]))
        #expect(store.removalInProgressIDs.isEmpty)
        #expect(store.removalFeedback == nil)
        #expect(playback.begunIDs == [song.id])
        #expect(playback.endedIDs == [song.id])
        #expect(await repository.fetchCount == 1)
    }

    @Test func repeatedRemovalIsIgnoredWhileTheIdentityIsInProgress() async {
        let song = presentationSong(title: "In Progress")
        let repository = PresentationTestRepository(songs: [song])
        let remover = SuspendedPresentationTestLibraryRemover(
            repository: repository
        )
        let playback = PresentationTestPlaybackInvalidator()
        let store = LibraryStore(
            repository: repository,
            initialState: .loaded([song])
        )

        let removalTask = Task {
            await store.remove(
                song,
                using: remover,
                playbackInvalidator: playback
            )
        }
        await remover.waitUntilStarted()

        #expect(store.removalInProgressIDs == [song.id])
        await store.remove(
            song,
            using: remover,
            playbackInvalidator: playback
        )
        #expect(await remover.removeCallCount == 1)

        await remover.finish()
        await removalTask.value
        #expect(store.removalInProgressIDs.isEmpty)
        #expect(store.state == .loaded([]))
    }

    @Test func busyRemovalLeavesPlaybackAndLibraryUnchanged() async {
        let song = presentationSong(title: "Busy")
        let repository = PresentationTestRepository(songs: [song])
        let remover = PresentationTestLibraryRemover(
            repository: repository,
            removeOutcomes: [.busy]
        )
        let playback = PresentationTestPlaybackInvalidator()
        let store = LibraryStore(
            repository: repository,
            initialState: .loaded([song])
        )

        await store.remove(
            song,
            using: remover,
            playbackInvalidator: playback
        )

        #expect(store.state == .loaded([song]))
        #expect(playback.begunIDs.isEmpty)
        #expect(playback.endedIDs.isEmpty)
        #expect(
            store.removalFeedback
                == .requestFailure(
                    LibraryRemovalRequestFailure(song: song, reason: .busy)
                )
        )
    }

    @Test func rejectedRemovalUnblocksPlaybackAndCanBeRetried() async throws {
        let song = presentationSong(title: "Retry")
        let repository = PresentationTestRepository(songs: [song])
        let remover = PresentationTestLibraryRemover(
            repository: repository,
            removeOutcomes: [.notAccepted, .removed]
        )
        let playback = PresentationTestPlaybackInvalidator()
        let store = LibraryStore(
            repository: repository,
            initialState: .loaded([song])
        )

        await store.remove(
            song,
            using: remover,
            playbackInvalidator: playback
        )
        let feedback = try #require(store.removalFeedback)
        await store.retryRemovalFeedback(
            feedback,
            using: remover,
            playbackInvalidator: playback
        )

        #expect(store.state == .loaded([]))
        #expect(store.removalFeedback == nil)
        #expect(playback.begunIDs == [song.id, song.id])
        #expect(playback.endedIDs == [song.id, song.id])
    }

    @Test func cleanupFailureKeepsSongAbsentAndRetryClearsIssue() async throws {
        let song = presentationSong(title: "Cleanup")
        let issue = LibraryRemovalIssue(id: song.id, title: song.title)
        let repository = PresentationTestRepository(songs: [song])
        let remover = PresentationTestLibraryRemover(
            repository: repository,
            removeOutcomes: [.pendingCleanup(issue)],
            retryOutcomes: [.completed]
        )
        let playback = PresentationTestPlaybackInvalidator()
        let store = LibraryStore(
            repository: repository,
            initialState: .loaded([song])
        )

        await store.remove(
            song,
            using: remover,
            playbackInvalidator: playback
        )
        let feedback = try #require(store.removalFeedback)
        #expect(store.state == .loaded([]))
        #expect(feedback == .cleanupIssue(issue))
        #expect(await repository.fetchCount == 1)

        await store.retryRemovalFeedback(
            feedback,
            using: remover,
            playbackInvalidator: playback
        )

        #expect(store.state == .loaded([]))
        #expect(store.removalFeedback == nil)
        #expect(await remover.retriedIDs == [song.id])
        #expect(await repository.fetchCount == 2)
    }

    @Test func removalConfirmationDescribesCurrentPlaybackConsequence() {
        let currentMessage = LibraryRemovalPresentation.confirmationMessage(
            songTitle: "Current",
            stopsPlayback: true
        )
        let otherMessage = LibraryRemovalPresentation.confirmationMessage(
            songTitle: "Other",
            stopsPlayback: false
        )

        #expect(currentMessage.contains("Playback will stop"))
        #expect(currentMessage.contains("managed audio and artwork"))
        #expect(currentMessage.contains("original file will not be changed"))
        #expect(!otherMessage.contains("Playback will stop"))
        #expect(otherMessage.contains("managed audio and artwork"))
        #expect(otherMessage.contains("original file will not be changed"))
    }

    @Test func cleanupFailureTextIsNonTechnicalAndActionable() {
        let issue = LibraryRemovalIssue(id: UUID(), title: "Cleanup")
        let feedback = LibraryRemovalFeedback.cleanupIssue(issue)
        let message = LibraryRemovalPresentation.feedbackMessage(feedback)

        #expect(
            LibraryRemovalPresentation.feedbackTitle(feedback)
                == "Cleanup Couldn’t Finish"
        )
        #expect(message.contains("Cleanup"))
        #expect(message.contains("managed files"))
        #expect(message.contains("Try again"))
    }

    @Test func removalPresentationNeverExposesInternalUUIDTitles() {
        let identifier = "00000000-0000-0000-0000-000000000004"
        let song = presentationSong(title: identifier)
        let texts = [
            LibraryRemovalPresentation.confirmationTitle(
                songTitle: identifier
            ),
            LibraryRemovalPresentation.confirmationMessage(
                songTitle: "\(identifier).m4a",
                stopsPlayback: false
            ),
            LibraryRemovalPresentation.feedbackMessage(
                .requestFailure(
                    LibraryRemovalRequestFailure(
                        song: song,
                        reason: .notAccepted
                    )
                )
            ),
            LibraryRemovalPresentation.feedbackMessage(
                .cleanupIssue(
                    LibraryRemovalIssue(id: song.id, title: identifier)
                )
            ),
        ]

        #expect(texts.allSatisfy { !$0.contains(identifier) })
        #expect(texts.allSatisfy { $0.contains("Unknown Title") })
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
    private var songs: [LibrarySong]
    private(set) var fetchCount = 0

    init(songs: [LibrarySong]) {
        self.songs = songs
    }

    func fetchSongs(locale: Locale) -> [LibrarySong] {
        fetchCount += 1
        return songs
    }

    func removeSong(id: UUID) {
        songs.removeAll { $0.id == id }
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

private actor PresentationTestLibraryRemover: LibraryRemoving {
    private let repository: PresentationTestRepository
    private var removeOutcomes: [LibraryRemovalOutcome]
    private var retryOutcomes: [LibraryRemovalRetryOutcome]
    private(set) var retriedIDs: [UUID] = []

    init(
        repository: PresentationTestRepository,
        removeOutcomes: [LibraryRemovalOutcome],
        retryOutcomes: [LibraryRemovalRetryOutcome] = []
    ) {
        self.repository = repository
        self.removeOutcomes = removeOutcomes
        self.retryOutcomes = retryOutcomes
    }

    func remove(
        id: UUID,
        beforeRemoval: @Sendable () async throws -> Void,
        afterAcceptance: @Sendable () async -> Void
    ) async -> LibraryRemovalOutcome {
        let outcome = removeOutcomes.isEmpty
            ? LibraryRemovalOutcome.notAccepted
            : removeOutcomes.removeFirst()
        guard outcome != .busy else {
            return outcome
        }

        do {
            try await beforeRemoval()
        } catch {
            return .notAccepted
        }

        switch outcome {
        case .removed, .pendingCleanup:
            await repository.removeSong(id: id)
            await afterAcceptance()
        case .missing, .busy, .notAccepted:
            break
        }
        return outcome
    }

    func retryRemoval(id: UUID) -> LibraryRemovalRetryOutcome {
        retriedIDs.append(id)
        return retryOutcomes.isEmpty ? .failed : retryOutcomes.removeFirst()
    }
}

private actor SuspendedPresentationTestLibraryRemover: LibraryRemoving {
    private let repository: PresentationTestRepository
    private var hasStarted = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var completion: CheckedContinuation<Void, Never>?
    private(set) var removeCallCount = 0

    init(repository: PresentationTestRepository) {
        self.repository = repository
    }

    func remove(
        id: UUID,
        beforeRemoval: @Sendable () async throws -> Void,
        afterAcceptance: @Sendable () async -> Void
    ) async -> LibraryRemovalOutcome {
        removeCallCount += 1
        do {
            try await beforeRemoval()
        } catch {
            return .notAccepted
        }
        hasStarted = true
        for waiter in startWaiters {
            waiter.resume()
        }
        startWaiters.removeAll()
        await withCheckedContinuation { continuation in
            completion = continuation
        }
        await repository.removeSong(id: id)
        await afterAcceptance()
        return .removed
    }

    func retryRemoval(id: UUID) -> LibraryRemovalRetryOutcome {
        .failed
    }

    func waitUntilStarted() async {
        guard !hasStarted else {
            return
        }
        await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }

    func finish() {
        completion?.resume()
        completion = nil
    }
}

@MainActor
private final class PresentationTestPlaybackInvalidator:
    PlaybackRemovalInvalidating {
    private(set) var begunIDs: [UUID] = []
    private(set) var endedIDs: [UUID] = []

    func beginRemovalInvalidation(for songID: UUID) async {
        begunIDs.append(songID)
    }

    func endRemovalInvalidation(for songID: UUID) {
        endedIDs.append(songID)
    }
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

private func presentationSong(title: String) -> LibrarySong {
    LibrarySong(
        id: UUID(),
        title: title,
        artist: nil,
        album: nil,
        durationSeconds: nil,
        artworkURL: nil,
        availability: .available(
            audioURL: URL(filePath: "/test/\(title).m4a")
        )
    )
}
