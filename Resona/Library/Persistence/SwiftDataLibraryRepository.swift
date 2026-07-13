import Foundation
import SwiftData

@ModelActor
actor SwiftDataLibraryRepository: LibraryRepository {
    private var resourceResolver: any LibraryResourceResolving =
        UnavailableLibraryResourceResolver()

    init(
        modelContainer: ModelContainer,
        resourceResolver: any LibraryResourceResolving
    ) {
        let modelContext = ModelContext(modelContainer)
        self.modelContainer = modelContainer
        modelExecutor = DefaultSerialModelExecutor(modelContext: modelContext)
        self.resourceResolver = resourceResolver
    }

    func fetchSongs(locale: Locale) async throws -> [LibrarySong] {
        let records = try modelContext.fetch(FetchDescriptor<LibrarySongRecord>())
        var songs: [LibrarySong] = []
        songs.reserveCapacity(records.count)

        for record in records {
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

            songs.append(
                LibrarySong(
                    id: record.id,
                    title: record.title,
                    artist: record.artist,
                    album: record.album,
                    durationSeconds: record.durationSeconds,
                    artworkURL: artworkURL,
                    availability: audioURL.map(SongAvailability.available)
                        ?? .unavailable
                )
            )
        }

        return LibrarySongSorting.sorted(songs, locale: locale)
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

    private func record(id: UUID) throws -> LibrarySongRecord? {
        let descriptor = FetchDescriptor<LibrarySongRecord>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }
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
