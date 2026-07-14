import Foundation
import Testing
@testable import Resona

@MainActor
struct LibraryRemovalServiceTests {
    @Test func mutationGateRejectsOverlapAndAcceptsWorkAfterRelease() async {
        let gate = LibraryMutationGate()
        let first = await gate.acquire()

        #expect(await gate.acquire() == .busy)
        if case let .acquired(reservation) = first {
            await gate.release(reservation)
        }
        #expect(await gate.acquire().reservation != nil)
    }

    @Test func acceptedRemovalCleansResourcesAndFinalizesIntent() async {
        let removal = testRemoval(1)
        let recorder = RemovalOperationRecorder()
        let repository = RemovalTestRepository(
            active: [removal],
            recorder: recorder
        )
        let mediaStore = RemovalTestMediaStore(
            resources: [removal],
            recorder: recorder
        )
        let service = makeService(
            repository: repository,
            mediaStore: mediaStore
        )

        let outcome = await service.remove(
            id: removal.id,
            afterAcceptance: {
                await recorder.record("accepted")
            }
        )

        #expect(outcome == .removed)
        #expect(await repository.activeIDs.isEmpty)
        #expect(await repository.pendingIDs.isEmpty)
        #expect(await mediaStore.audioFilenames.isEmpty)
        #expect(await mediaStore.artworkFilenames.isEmpty)
        let acceptanceIndex = await recorder.events.firstIndex(of: "accepted")
        let cleanupIndex = await recorder.events.firstIndex(
            of: "cleanup-\(removal.id.uuidString)"
        )
        #expect(acceptanceIndex != nil)
        #expect(cleanupIndex != nil)
        if let acceptanceIndex, let cleanupIndex {
            #expect(acceptanceIndex < cleanupIndex)
        }
    }

    @Test func unavailableResourcesAreAlreadyCleanedUp() async {
        let removal = testRemoval(2)
        let repository = RemovalTestRepository(active: [removal])
        let mediaStore = RemovalTestMediaStore()
        let service = makeService(
            repository: repository,
            mediaStore: mediaStore
        )

        #expect(await service.remove(id: removal.id) == .removed)
        #expect(await repository.pendingIDs.isEmpty)
    }

    @Test func failedDurableAcceptanceLeavesActiveSongAndReleasesGate() async {
        let removal = testRemoval(3)
        let repository = RemovalTestRepository(
            active: [removal],
            beginFailuresRemaining: 1
        )
        let mediaStore = RemovalTestMediaStore(resources: [removal])
        let gate = LibraryMutationGate()
        let service = LibraryRemovalService(
            repository: repository,
            mediaStore: mediaStore,
            mutationGate: gate
        )

        #expect(await service.remove(id: removal.id) == .notAccepted)
        #expect(await repository.activeIDs == [removal.id])
        #expect(await repository.pendingIDs.isEmpty)
        #expect(await gate.acquire().reservation != nil)
    }

    @Test func partialCleanupKeepsIntentAndExplicitRetryConverges() async {
        let removal = testRemoval(4)
        let issue = LibraryRemovalIssue(id: removal.id, title: removal.title)
        let repository = RemovalTestRepository(active: [removal])
        let mediaStore = RemovalTestMediaStore(
            resources: [removal],
            artworkCleanupFailuresRemaining: 1
        )
        let service = makeService(
            repository: repository,
            mediaStore: mediaStore
        )

        #expect(
            await service.remove(id: removal.id) == .pendingCleanup(issue)
        )
        #expect(await repository.activeIDs.isEmpty)
        #expect(await repository.pendingIDs == [removal.id])
        #expect(await mediaStore.audioFilenames.isEmpty)
        #expect(
            await mediaStore.artworkFilenames
                == Set([removal.managedArtworkFilename].compactMap { $0 })
        )

        #expect(await service.retryRemoval(id: removal.id) == .completed)
        #expect(await repository.pendingIDs.isEmpty)
        #expect(await mediaStore.artworkFilenames.isEmpty)
    }

    @Test func finalizationFailureKeepsIntentForIdempotentRetry() async {
        let removal = testRemoval(5)
        let issue = LibraryRemovalIssue(id: removal.id, title: removal.title)
        let repository = RemovalTestRepository(
            active: [removal],
            finalizeFailuresRemaining: 1
        )
        let mediaStore = RemovalTestMediaStore(resources: [removal])
        let service = makeService(
            repository: repository,
            mediaStore: mediaStore
        )

        #expect(
            await service.remove(id: removal.id) == .pendingCleanup(issue)
        )
        #expect(await repository.pendingIDs == [removal.id])
        #expect(await mediaStore.audioFilenames.isEmpty)
        #expect(await mediaStore.artworkFilenames.isEmpty)

        #expect(await service.retryRemoval(id: removal.id) == .completed)
        #expect(await repository.pendingIDs.isEmpty)
    }

    @Test func launchReconciliationRetriesInOrderBeforeOrphanCleanup() async throws {
        let first = testRemoval(6)
        let second = testRemoval(7)
        let recorder = RemovalOperationRecorder()
        let repository = RemovalTestRepository(
            pending: [second, first],
            recorder: recorder
        )
        let mediaStore = RemovalTestMediaStore(
            resources: [first, second],
            artworkCleanupFailuresRemaining: 1,
            recorder: recorder
        )
        let service = makeService(
            repository: repository,
            mediaStore: mediaStore
        )

        let issues = try await service.reconcileLibrary()

        #expect(issues == [LibraryRemovalIssue(id: first.id, title: first.title)])
        #expect(await repository.pendingIDs == [first.id])
        #expect(
            await mediaStore.lastReconciliationReferences
                == LibraryResourceReferences(
                    audioFilenames: [first.managedAudioFilename],
                    artworkFilenames: Set(
                        [first.managedArtworkFilename].compactMap { $0 }
                    )
                )
        )
        #expect(
            await recorder.events == [
                "pending",
                "cleanup-\(first.id.uuidString)",
                "cleanup-\(second.id.uuidString)",
                "finalize-\(second.id.uuidString)",
                "references",
                "reconcile",
            ]
        )
    }

    @Test func busyRemovalDoesNotRunPreparationOrChangeRepository() async throws {
        let removal = testRemoval(8)
        let repository = RemovalTestRepository(active: [removal])
        let mediaStore = RemovalTestMediaStore(resources: [removal])
        let gate = LibraryMutationGate()
        let service = LibraryRemovalService(
            repository: repository,
            mediaStore: mediaStore,
            mutationGate: gate
        )
        let held = try #require((await gate.acquire()).reservation)

        #expect(await service.remove(id: removal.id) == .busy)
        #expect(await service.retryRemoval(id: removal.id) == .busy)
        do {
            _ = try await service.reconcileLibrary()
            Issue.record("Expected reconciliation to report the active mutation")
        } catch let error as LibraryRemovalServiceError {
            #expect(error == .operationInProgress)
        }
        #expect(await repository.activeIDs == [removal.id])
        #expect(await mediaStore.cleanupCallCount == 0)
        await gate.release(held)
    }

    @Test func cancellationBeforeAcceptanceReleasesMutationGate() async {
        let removal = testRemoval(9)
        let repository = RemovalTestRepository(active: [removal])
        let mediaStore = RemovalTestMediaStore(resources: [removal])
        let gate = LibraryMutationGate()
        let blocker = RemovalCancellationBlocker()
        let service = LibraryRemovalService(
            repository: repository,
            mediaStore: mediaStore,
            mutationGate: gate
        )
        let task = Task {
            await service.remove(id: removal.id) {
                try await blocker.wait()
            }
        }
        while !(await blocker.hasStarted) {
            await Task.yield()
        }

        task.cancel()

        #expect(await task.value == .notAccepted)
        #expect(await repository.activeIDs == [removal.id])
        #expect(await gate.acquire().reservation != nil)
    }

    @Test func cancellationAfterAcceptanceKeepsCleanupOwnership() async {
        let removal = testRemoval(10)
        let issue = LibraryRemovalIssue(id: removal.id, title: removal.title)
        let repository = RemovalTestRepository(active: [removal])
        let blocker = RemovalCancellationBlocker()
        let mediaStore = RemovalTestMediaStore(
            resources: [removal],
            cleanupBlocker: blocker
        )
        let gate = LibraryMutationGate()
        let service = LibraryRemovalService(
            repository: repository,
            mediaStore: mediaStore,
            mutationGate: gate
        )
        let task = Task {
            await service.remove(id: removal.id)
        }
        while !(await blocker.hasStarted) {
            await Task.yield()
        }

        task.cancel()

        #expect(await task.value == .pendingCleanup(issue))
        #expect(await repository.activeIDs.isEmpty)
        #expect(await repository.pendingIDs == [removal.id])
        #expect(await gate.acquire().reservation != nil)
    }

    private func makeService(
        repository: RemovalTestRepository,
        mediaStore: RemovalTestMediaStore
    ) -> LibraryRemovalService {
        LibraryRemovalService(
            repository: repository,
            mediaStore: mediaStore,
            mutationGate: LibraryMutationGate()
        )
    }
}

private extension LibraryMutationAcquisition {
    var reservation: LibraryMutationReservation? {
        guard case let .acquired(reservation) = self else {
            return nil
        }
        return reservation
    }
}

private actor RemovalTestRepository: LibraryRepository {
    private var active: [UUID: LibrarySongRemoval]
    private var pending: [UUID: LibrarySongRemoval]
    private var beginFailuresRemaining: Int
    private var finalizeFailuresRemaining: Int
    private let recorder: RemovalOperationRecorder?

    init(
        active: [LibrarySongRemoval] = [],
        pending: [LibrarySongRemoval] = [],
        beginFailuresRemaining: Int = 0,
        finalizeFailuresRemaining: Int = 0,
        recorder: RemovalOperationRecorder? = nil
    ) {
        self.active = Dictionary(uniqueKeysWithValues: active.map { ($0.id, $0) })
        self.pending = Dictionary(uniqueKeysWithValues: pending.map { ($0.id, $0) })
        self.beginFailuresRemaining = beginFailuresRemaining
        self.finalizeFailuresRemaining = finalizeFailuresRemaining
        self.recorder = recorder
    }

    var activeIDs: Set<UUID> { Set(active.keys) }
    var pendingIDs: Set<UUID> { Set(pending.keys) }

    func fetchSongs(locale: Locale) -> [LibrarySong] { [] }

    func resourceReferences() async -> LibraryResourceReferences {
        await recorder?.record("references")
        return LibraryResourceReferences(
            audioFilenames: Set(
                active.values.map(\.managedAudioFilename)
                    + pending.values.map(\.managedAudioFilename)
            ),
            artworkFilenames: Set(
                active.values.compactMap(\.managedArtworkFilename)
                    + pending.values.compactMap(\.managedArtworkFilename)
            )
        )
    }

    func duplicateCandidates(
        matching fingerprint: ContentFingerprint
    ) -> [LibraryDuplicateCandidate] { [] }

    func insert(_ draft: LibrarySongDraft) {}
    func restore(_ draft: LibrarySongDraft) {}

    func beginRemoval(id: UUID) throws -> LibraryRemovalBeginning {
        if beginFailuresRemaining > 0 {
            beginFailuresRemaining -= 1
            throw RemovalTestError.injected
        }
        guard let removal = active.removeValue(forKey: id) else {
            return .missing
        }
        pending[id] = removal
        return .accepted(removal)
    }

    func pendingRemovals() async -> [LibrarySongRemoval] {
        await recorder?.record("pending")
        return pending.values.sorted { $0.id.uuidString < $1.id.uuidString }
    }

    func finalizeRemoval(id: UUID) async throws {
        await recorder?.record("finalize-\(id.uuidString)")
        if finalizeFailuresRemaining > 0 {
            finalizeFailuresRemaining -= 1
            throw RemovalTestError.injected
        }
        pending[id] = nil
    }
}

private actor RemovalTestMediaStore: ManagedMediaStoring {
    private var storedAudioFilenames: Set<String>
    private var storedArtworkFilenames: Set<String>
    private var artworkCleanupFailuresRemaining: Int
    private let recorder: RemovalOperationRecorder?
    private let cleanupBlocker: RemovalCancellationBlocker?
    private(set) var cleanupCallCount = 0
    private(set) var lastReconciliationReferences: LibraryResourceReferences?

    init(
        resources: [LibrarySongRemoval] = [],
        artworkCleanupFailuresRemaining: Int = 0,
        recorder: RemovalOperationRecorder? = nil,
        cleanupBlocker: RemovalCancellationBlocker? = nil
    ) {
        storedAudioFilenames = Set(resources.map(\.managedAudioFilename))
        storedArtworkFilenames = Set(
            resources.compactMap(\.managedArtworkFilename)
        )
        self.artworkCleanupFailuresRemaining = artworkCleanupFailuresRemaining
        self.recorder = recorder
        self.cleanupBlocker = cleanupBlocker
    }

    var audioFilenames: Set<String> { storedAudioFilenames }
    var artworkFilenames: Set<String> { storedArtworkFilenames }

    func audioURL(for managedFilename: String) -> URL? {
        storedAudioFilenames.contains(managedFilename)
            ? URL(filePath: "/managed/audio/\(managedFilename)")
            : nil
    }

    func artworkURL(for managedFilename: String) -> URL? {
        storedArtworkFilenames.contains(managedFilename)
            ? URL(filePath: "/managed/artwork/\(managedFilename)")
            : nil
    }

    func stagingURL(operationID: UUID, candidateID: UUID) throws -> URL {
        throw RemovalTestError.unsupported
    }

    func commitAudio(
        from stagingURL: URL,
        songID: UUID,
        fileExtension: String
    ) throws -> String {
        throw RemovalTestError.unsupported
    }

    func commitArtwork(
        from stagingURL: URL,
        songID: UUID,
        fileExtension: String
    ) throws -> String {
        throw RemovalTestError.unsupported
    }

    func contentsEqual(
        stagedURL: URL,
        managedAudioFilename: String
    ) -> Bool { false }

    func removeResources(
        audioFilename: String?,
        artworkFilename: String?
    ) async throws {
        cleanupCallCount += 1
        let identity = audioFilename?
            .split(separator: ".", maxSplits: 1)
            .first
            .map(String.init) ?? "unknown"
        await recorder?.record("cleanup-\(identity)")
        try await cleanupBlocker?.wait()
        if let audioFilename {
            storedAudioFilenames.remove(audioFilename)
        }
        if artworkFilename != nil, artworkCleanupFailuresRemaining > 0 {
            artworkCleanupFailuresRemaining -= 1
            throw RemovalTestError.injected
        }
        if let artworkFilename {
            storedArtworkFilenames.remove(artworkFilename)
        }
    }

    func removeStagingOperation(id: UUID) {}

    func reconcile(references: LibraryResourceReferences) async {
        await recorder?.record("reconcile")
        lastReconciliationReferences = references
        storedAudioFilenames.formIntersection(references.audioFilenames)
        storedArtworkFilenames.formIntersection(references.artworkFilenames)
    }
}

private actor RemovalOperationRecorder {
    private(set) var events: [String] = []

    func record(_ event: String) {
        events.append(event)
    }
}

private actor RemovalCancellationBlocker {
    private(set) var hasStarted = false

    func wait() async throws {
        hasStarted = true
        while true {
            try Task.checkCancellation()
            await Task.yield()
        }
    }
}

private enum RemovalTestError: Error {
    case injected
    case unsupported
}

nonisolated private func testRemoval(_ value: UInt8) -> LibrarySongRemoval {
    let id = UUID(
        uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value)
    )
    return LibrarySongRemoval(
        id: id,
        title: "Song \(value)",
        managedAudioFilename: "\(id.uuidString).m4a",
        managedArtworkFilename: "\(id.uuidString).jpg"
    )
}
