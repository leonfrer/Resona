import Foundation
import SwiftData
import Testing
@testable import Resona

@Suite(.serialized)
@MainActor
struct ResonaPersistenceTests {
    @Test func currentSchemaContainsOnlyLibraryModels() {
        let modelNames = Set(ResonaSchema.current.entities.map(\.name))

        #expect(
            modelNames
                == ["LibrarySongRecord", "LibrarySongRemovalRecord"]
        )
    }

    @Test func preservesSongIdentityAcrossContainerRecreation() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let storeURL = directory.appending(path: "Resona.store")
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer {
            try? FileManager.default.removeItem(at: directory)
        }
        let id = UUID()

        try await insertSong(id: id, into: storeURL)

        let reopenedContainer = try ResonaModelContainer.make(storeURL: storeURL)
        let repository = SwiftDataLibraryRepository(
            modelContainer: reopenedContainer,
            resourceResolver: StubLibraryResourceResolver()
        )
        let songs = try await repository.fetchSongs(
            locale: Locale(identifier: "en_US")
        )

        #expect(songs.count == 1)
        #expect(songs[0].id == id)
        #expect(songs[0].title == "Persistent Song")
    }

    private func insertSong(id: UUID, into storeURL: URL) async throws {
        let container = try ResonaModelContainer.make(storeURL: storeURL)
        let repository = SwiftDataLibraryRepository(
            modelContainer: container,
            resourceResolver: StubLibraryResourceResolver()
        )
        try await repository.insert(
            LibrarySongDraft(
                id: id,
                fingerprint: ContentFingerprint(
                    digest: "persistent",
                    byteCount: 256
                ),
                managedAudioFilename: "persistent.m4a",
                title: "Persistent Song",
                artist: nil,
                album: nil,
                durationSeconds: 60,
                managedArtworkFilename: nil
            )
        )
    }
}
