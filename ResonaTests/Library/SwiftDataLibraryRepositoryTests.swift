import Foundation
import Testing
@testable import Resona

@MainActor
struct SwiftDataLibraryRepositoryTests {
    @Test func roundTripsSongAndDerivesResourceAvailability() async throws {
        let container = try ResonaModelContainer.make(isStoredInMemoryOnly: true)
        let audioURL = URL(fileURLWithPath: "/tmp/managed/song.m4a")
        let artworkURL = URL(fileURLWithPath: "/tmp/managed/song.jpg")
        let resolver = StubLibraryResourceResolver(
            audioURLs: ["song.m4a": audioURL],
            artworkURLs: ["song.jpg": artworkURL]
        )
        let repository = SwiftDataLibraryRepository(
            modelContainer: container,
            resourceResolver: resolver
        )
        let id = UUID()

        try await repository.insert(
            draft(
                id: id,
                digest: "ABC123",
                audioFilename: "song.m4a",
                title: "Song",
                artworkFilename: "song.jpg"
            )
        )

        let songs = try await repository.fetchSongs(
            locale: Locale(identifier: "en_US")
        )

        #expect(
            songs == [
                LibrarySong(
                    id: id,
                    title: "Song",
                    artist: "Artist",
                    album: "Album",
                    durationSeconds: 123,
                    artworkURL: artworkURL,
                    availability: .available(audioURL: audioURL)
                ),
            ]
        )
    }

    @Test func reportsUnavailableWhenManagedAudioCannotBeResolved() async throws {
        let container = try ResonaModelContainer.make(isStoredInMemoryOnly: true)
        let repository = SwiftDataLibraryRepository(
            modelContainer: container,
            resourceResolver: StubLibraryResourceResolver()
        )
        let id = UUID()
        try await repository.insert(
            draft(
                id: id,
                digest: "missing",
                audioFilename: "missing.mp3",
                title: "Missing"
            )
        )

        let songs = try await repository.fetchSongs(
            locale: Locale(identifier: "en_US")
        )

        #expect(songs.count == 1)
        #expect(songs[0].id == id)
        #expect(songs[0].availability == .unavailable)
    }

    @Test func resolvesOneSongByStableIdentityWithFreshResources() async throws {
        let container = try ResonaModelContainer.make(isStoredInMemoryOnly: true)
        let audioURL = URL(fileURLWithPath: "/tmp/managed/fresh.m4a")
        let artworkURL = URL(fileURLWithPath: "/tmp/managed/fresh.jpg")
        let resolver = StubLibraryResourceResolver(
            audioURLs: ["fresh.m4a": audioURL],
            artworkURLs: ["fresh.jpg": artworkURL]
        )
        let repository = SwiftDataLibraryRepository(
            modelContainer: container,
            resourceResolver: resolver
        )
        let id = UUID()
        try await repository.insert(
            draft(
                id: id,
                digest: "fresh",
                audioFilename: "fresh.m4a",
                title: "Fresh Song",
                artworkFilename: "fresh.jpg"
            )
        )

        let song = try await repository.song(id: id)

        #expect(song?.id == id)
        #expect(song?.title == "Fresh Song")
        #expect(song?.artworkURL == artworkURL)
        #expect(song?.availability == .available(audioURL: audioURL))
        #expect(try await repository.song(id: UUID()) == nil)
    }

    @Test func reportsAllManagedResourceReferences() async throws {
        let container = try ResonaModelContainer.make(isStoredInMemoryOnly: true)
        let repository = SwiftDataLibraryRepository(
            modelContainer: container,
            resourceResolver: StubLibraryResourceResolver()
        )
        try await repository.insert(
            draft(
                id: UUID(),
                digest: "first",
                audioFilename: "first.m4a",
                title: "First",
                artworkFilename: "first.jpg"
            )
        )
        try await repository.insert(
            draft(
                id: UUID(),
                digest: "second",
                audioFilename: "second.mp3",
                title: "Second"
            )
        )

        let references = try await repository.resourceReferences()

        #expect(references.audioFilenames == ["first.m4a", "second.mp3"])
        #expect(references.artworkFilenames == ["first.jpg"])
    }

    @Test func findsOnlyMatchingFingerprintCandidates() async throws {
        let container = try ResonaModelContainer.make(isStoredInMemoryOnly: true)
        let firstAudioURL = URL(fileURLWithPath: "/tmp/managed/first.wav")
        let repository = SwiftDataLibraryRepository(
            modelContainer: container,
            resourceResolver: StubLibraryResourceResolver(
                audioURLs: ["first.wav": firstAudioURL]
            )
        )
        let matchingID = UUID()
        try await repository.insert(
            draft(
                id: matchingID,
                digest: "AABBCC",
                byteCount: 42,
                audioFilename: "first.wav",
                title: "First"
            )
        )
        try await repository.insert(
            draft(
                id: UUID(),
                digest: "different",
                byteCount: 42,
                audioFilename: "second.wav",
                title: "Second"
            )
        )

        let candidates = try await repository.duplicateCandidates(
            matching: ContentFingerprint(digest: "aabbcc", byteCount: 42)
        )

        #expect(candidates.count == 1)
        #expect(candidates[0].id == matchingID)
        #expect(candidates[0].managedAudioURL == firstAudioURL)
    }

    @Test func restoresMetadataAndResourceWithoutChangingIdentity() async throws {
        let container = try ResonaModelContainer.make(isStoredInMemoryOnly: true)
        let restoredURL = URL(fileURLWithPath: "/tmp/managed/restored.aiff")
        let repository = SwiftDataLibraryRepository(
            modelContainer: container,
            resourceResolver: StubLibraryResourceResolver(
                audioURLs: ["restored.aiff": restoredURL]
            )
        )
        let id = UUID()
        try await repository.insert(
            draft(
                id: id,
                digest: "same-content",
                audioFilename: "missing.aiff",
                title: "Old Title"
            )
        )

        try await repository.restore(
            draft(
                id: id,
                digest: "same-content",
                audioFilename: "restored.aiff",
                title: "New Title"
            )
        )

        let songs = try await repository.fetchSongs(
            locale: Locale(identifier: "en_US")
        )
        #expect(songs.count == 1)
        #expect(songs[0].id == id)
        #expect(songs[0].title == "New Title")
        #expect(songs[0].availability == .available(audioURL: restoredURL))
    }

    @Test func rejectsDuplicateIdentityAndMissingRestoreTarget() async throws {
        let container = try ResonaModelContainer.make(isStoredInMemoryOnly: true)
        let repository = SwiftDataLibraryRepository(
            modelContainer: container,
            resourceResolver: StubLibraryResourceResolver()
        )
        let id = UUID()
        let original = draft(
            id: id,
            digest: "original",
            audioFilename: "original.mp3",
            title: "Original"
        )
        try await repository.insert(original)

        do {
            try await repository.insert(original)
            Issue.record("Expected a duplicate identity error")
        } catch let error as LibraryRepositoryError {
            #expect(error == .duplicateIdentity(id))
        }

        let missingID = UUID()
        do {
            try await repository.restore(
                draft(
                    id: missingID,
                    digest: "missing",
                    audioFilename: "missing.mp3",
                    title: "Missing"
                )
            )
            Issue.record("Expected a missing song error")
        } catch let error as LibraryRepositoryError {
            #expect(error == .missingSong(missingID))
        }
    }

    @Test func beginsRemovalAndExcludesPendingIdentityFromActiveQueries() async throws {
        let container = try ResonaModelContainer.make(isStoredInMemoryOnly: true)
        let repository = SwiftDataLibraryRepository(
            modelContainer: container,
            resourceResolver: StubLibraryResourceResolver()
        )
        let id = UUID()
        let songDraft = draft(
            id: id,
            digest: "removed-content",
            audioFilename: "removed.m4a",
            title: "Removed Song",
            artworkFilename: "removed.jpg"
        )
        try await repository.insert(songDraft)

        let result = try await repository.beginRemoval(id: id)

        #expect(
            result == .accepted(
                LibrarySongRemoval(
                    id: id,
                    title: "Removed Song",
                    managedAudioFilename: "removed.m4a",
                    managedArtworkFilename: "removed.jpg"
                )
            )
        )
        #expect(try await repository.fetchSongs(locale: .current).isEmpty)
        #expect(try await repository.song(id: id) == nil)
        #expect(
            try await repository.duplicateCandidates(
                matching: songDraft.fingerprint
            ).isEmpty
        )
        #expect(
            try await repository.pendingRemovals() == [
                LibrarySongRemoval(
                    id: id,
                    title: "Removed Song",
                    managedAudioFilename: "removed.m4a",
                    managedArtworkFilename: "removed.jpg"
                ),
            ]
        )
        let references = try await repository.resourceReferences()
        #expect(references.audioFilenames == ["removed.m4a"])
        #expect(references.artworkFilenames == ["removed.jpg"])
        #expect(try await repository.beginRemoval(id: id) == .missing)
    }

    @Test func pendingRemovalsAreDeterministicAndFinalizationIsIdempotent() async throws {
        let container = try ResonaModelContainer.make(isStoredInMemoryOnly: true)
        let repository = SwiftDataLibraryRepository(
            modelContainer: container,
            resourceResolver: StubLibraryResourceResolver()
        )
        let laterID = UUID(
            uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2)
        )
        let earlierID = UUID(
            uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)
        )
        try await repository.insert(
            draft(
                id: laterID,
                digest: "later",
                audioFilename: "later.mp3",
                title: "Later"
            )
        )
        try await repository.insert(
            draft(
                id: earlierID,
                digest: "earlier",
                audioFilename: "earlier.mp3",
                title: "Earlier"
            )
        )
        _ = try await repository.beginRemoval(id: laterID)
        _ = try await repository.beginRemoval(id: earlierID)

        #expect(
            try await repository.pendingRemovals().map(\.id)
                == [earlierID, laterID]
        )

        try await repository.finalizeRemoval(id: earlierID)
        try await repository.finalizeRemoval(id: earlierID)

        #expect(try await repository.pendingRemovals().map(\.id) == [laterID])
        #expect(try await repository.beginRemoval(id: UUID()) == .missing)
    }

    @Test func failedBeginRemovalRollsBackActiveRecordAndTombstone() async throws {
        let container = try ResonaModelContainer.make(isStoredInMemoryOnly: true)
        let repository = SwiftDataLibraryRepository(
            modelContainer: container,
            resourceResolver: StubLibraryResourceResolver(),
            beforeSave: { operation in
                if operation == .beginRemoval {
                    throw InjectedRepositoryError.saveFailed
                }
            }
        )
        let id = UUID()
        try await repository.insert(
            draft(
                id: id,
                digest: "preserved",
                audioFilename: "preserved.wav",
                title: "Preserved"
            )
        )

        await #expect(throws: InjectedRepositoryError.saveFailed) {
            try await repository.beginRemoval(id: id)
        }

        #expect(try await repository.song(id: id)?.title == "Preserved")
        #expect(try await repository.pendingRemovals().isEmpty)
    }

    @Test func failedFinalizationKeepsPendingRemovalForRetry() async throws {
        let container = try ResonaModelContainer.make(isStoredInMemoryOnly: true)
        let failingRepository = SwiftDataLibraryRepository(
            modelContainer: container,
            resourceResolver: StubLibraryResourceResolver(),
            beforeSave: { operation in
                if operation == .finalizeRemoval {
                    throw InjectedRepositoryError.saveFailed
                }
            }
        )
        let id = UUID()
        try await failingRepository.insert(
            draft(
                id: id,
                digest: "pending",
                audioFilename: "pending.aiff",
                title: "Pending"
            )
        )
        _ = try await failingRepository.beginRemoval(id: id)

        await #expect(throws: InjectedRepositoryError.saveFailed) {
            try await failingRepository.finalizeRemoval(id: id)
        }

        #expect(try await failingRepository.pendingRemovals().map(\.id) == [id])

        let retryRepository = SwiftDataLibraryRepository(
            modelContainer: container,
            resourceResolver: StubLibraryResourceResolver()
        )
        try await retryRepository.finalizeRemoval(id: id)
        #expect(try await retryRepository.pendingRemovals().isEmpty)
    }

    private func draft(
        id: UUID,
        digest: String,
        byteCount: Int64 = 128,
        audioFilename: String,
        title: String,
        artworkFilename: String? = nil
    ) -> LibrarySongDraft {
        LibrarySongDraft(
            id: id,
            fingerprint: ContentFingerprint(
                digest: digest,
                byteCount: byteCount
            ),
            managedAudioFilename: audioFilename,
            title: title,
            artist: "Artist",
            album: "Album",
            durationSeconds: 123,
            managedArtworkFilename: artworkFilename
        )
    }
}

private enum InjectedRepositoryError: Error {
    case saveFailed
}
