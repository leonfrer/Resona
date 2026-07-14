import Foundation
import SwiftData

@ModelActor
actor SwiftDataLibraryRepository: LibraryRepository {
    private var resourceResolver: any LibraryResourceResolving =
        UnavailableLibraryResourceResolver()
    private var beforeSave: @Sendable (
        LibraryRepositorySaveOperation
    ) throws -> Void = { _ in }

    init(
        modelContainer: ModelContainer,
        resourceResolver: any LibraryResourceResolving,
        beforeSave: @escaping @Sendable (
            LibraryRepositorySaveOperation
        ) throws -> Void = { _ in }
    ) {
        let modelContext = ModelContext(modelContainer)
        self.modelContainer = modelContainer
        modelExecutor = DefaultSerialModelExecutor(modelContext: modelContext)
        self.resourceResolver = resourceResolver
        self.beforeSave = beforeSave
    }

    func fetchSongs(locale: Locale) async throws -> [LibrarySong] {
        let records = try modelContext.fetch(FetchDescriptor<LibrarySongRecord>())
        var songs: [LibrarySong] = []
        songs.reserveCapacity(records.count)

        for record in records {
            songs.append(await librarySong(from: record))
        }

        return LibrarySongSorting.sorted(songs, locale: locale)
    }

    func song(id: UUID) async throws -> LibrarySong? {
        guard let record = try record(id: id) else {
            return nil
        }
        return await librarySong(from: record)
    }

    func resourceReferences() throws -> LibraryResourceReferences {
        let activeRecords = try modelContext.fetch(
            FetchDescriptor<LibrarySongRecord>()
        )
        let removalRecords = try modelContext.fetch(
            FetchDescriptor<LibrarySongRemovalRecord>()
        )
        return LibraryResourceReferences(
            audioFilenames: Set(
                activeRecords.map(\.managedAudioFilename)
                    + removalRecords.map(\.managedAudioFilename)
            ),
            artworkFilenames: Set(
                activeRecords.compactMap(\.managedArtworkFilename)
                    + removalRecords.compactMap(\.managedArtworkFilename)
            )
        )
    }

    func duplicateCandidates(
        matching fingerprint: ContentFingerprint
    ) async throws -> [LibraryDuplicateCandidate] {
        let digest = fingerprint.digest
        let byteCount = fingerprint.byteCount
        let descriptor = FetchDescriptor<LibrarySongRecord>(
            predicate: #Predicate {
                $0.contentDigest == digest && $0.byteCount == byteCount
            }
        )
        let records = try modelContext.fetch(descriptor)
        var candidates: [LibraryDuplicateCandidate] = []
        candidates.reserveCapacity(records.count)

        for record in records {
            let audioURL = await resourceResolver.audioURL(
                for: record.managedAudioFilename
            )
            candidates.append(
                LibraryDuplicateCandidate(
                    id: record.id,
                    fingerprint: ContentFingerprint(
                        digest: record.contentDigest,
                        byteCount: record.byteCount
                    ),
                    managedAudioFilename: record.managedAudioFilename,
                    managedAudioURL: audioURL
                )
            )
        }

        return candidates.sorted {
            $0.id.uuidString < $1.id.uuidString
        }
    }

    func insert(_ draft: LibrarySongDraft) throws {
        guard try record(id: draft.id) == nil else {
            throw LibraryRepositoryError.duplicateIdentity(draft.id)
        }

        modelContext.insert(LibrarySongRecord(draft: draft))
        try modelContext.save()
    }

    func restore(_ draft: LibrarySongDraft) throws {
        guard let record = try record(id: draft.id) else {
            throw LibraryRepositoryError.missingSong(draft.id)
        }

        record.update(from: draft)
        try modelContext.save()
    }

    func beginRemoval(id: UUID) throws -> LibraryRemovalBeginning {
        guard let activeRecord = try record(id: id) else {
            return .missing
        }

        let removal = LibrarySongRemoval(record: activeRecord)
        modelContext.insert(LibrarySongRemovalRecord(removal: removal))
        modelContext.delete(activeRecord)

        do {
            try beforeSave(.beginRemoval)
            try modelContext.save()
            return .accepted(removal)
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    func pendingRemovals() throws -> [LibrarySongRemoval] {
        let records = try modelContext.fetch(
            FetchDescriptor<LibrarySongRemovalRecord>()
        )
        return records
            .map(LibrarySongRemoval.init)
            .sorted { $0.id.uuidString < $1.id.uuidString }
    }

    func finalizeRemoval(id: UUID) throws {
        guard let removalRecord = try removalRecord(id: id) else {
            return
        }

        modelContext.delete(removalRecord)
        do {
            try beforeSave(.finalizeRemoval)
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    private func record(id: UUID) throws -> LibrarySongRecord? {
        let descriptor = FetchDescriptor<LibrarySongRecord>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    private func removalRecord(id: UUID) throws -> LibrarySongRemovalRecord? {
        let descriptor = FetchDescriptor<LibrarySongRemovalRecord>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    private func librarySong(
        from record: LibrarySongRecord
    ) async -> LibrarySong {
        let audioURL = await resourceResolver.audioURL(
            for: record.managedAudioFilename
        )
        let artworkURL: URL?
        if let managedArtworkFilename = record.managedArtworkFilename {
            artworkURL = await resourceResolver.artworkURL(
                for: managedArtworkFilename
            )
        } else {
            artworkURL = nil
        }

        return LibrarySong(
            id: record.id,
            title: record.title,
            artist: record.artist,
            album: record.album,
            durationSeconds: record.durationSeconds,
            artworkURL: artworkURL,
            availability: audioURL.map(SongAvailability.available)
                ?? .unavailable
        )
    }
}

nonisolated enum LibraryRepositorySaveOperation: Equatable, Sendable {
    case beginRemoval
    case finalizeRemoval
}

private extension LibrarySongRecord {
    convenience init(draft: LibrarySongDraft) {
        self.init(
            id: draft.id,
            contentDigest: draft.fingerprint.digest,
            byteCount: draft.fingerprint.byteCount,
            managedAudioFilename: draft.managedAudioFilename,
            title: draft.title,
            artist: draft.artist,
            album: draft.album,
            durationSeconds: draft.durationSeconds,
            managedArtworkFilename: draft.managedArtworkFilename
        )
    }

    func update(from draft: LibrarySongDraft) {
        contentDigest = draft.fingerprint.digest
        byteCount = draft.fingerprint.byteCount
        managedAudioFilename = draft.managedAudioFilename
        title = draft.title
        artist = draft.artist
        album = draft.album
        durationSeconds = draft.durationSeconds
        managedArtworkFilename = draft.managedArtworkFilename
    }
}

private extension LibrarySongRemoval {
    nonisolated init(record: LibrarySongRecord) {
        self.init(
            id: record.id,
            title: record.title,
            managedAudioFilename: record.managedAudioFilename,
            managedArtworkFilename: record.managedArtworkFilename
        )
    }

    nonisolated init(record: LibrarySongRemovalRecord) {
        self.init(
            id: record.id,
            title: record.title,
            managedAudioFilename: record.managedAudioFilename,
            managedArtworkFilename: record.managedArtworkFilename
        )
    }
}

private extension LibrarySongRemovalRecord {
    convenience init(removal: LibrarySongRemoval) {
        self.init(
            id: removal.id,
            title: removal.title,
            managedAudioFilename: removal.managedAudioFilename,
            managedArtworkFilename: removal.managedArtworkFilename
        )
    }
}
