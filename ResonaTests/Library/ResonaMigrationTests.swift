import Foundation
import SwiftData
import Testing
@testable import Resona

@Suite(.serialized)
@MainActor
struct ResonaMigrationTests {
    @Test func migratesV0StoreThroughCompleteChainWithoutLosingItems() throws {
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
        let timestamp = Date(timeIntervalSince1970: 1_234_567)

        try createV0Store(at: storeURL, timestamp: timestamp)

        let migratedContainer = try ResonaModelContainer.make(storeURL: storeURL)
        let context = ModelContext(migratedContainer)
        let items = try context.fetch(FetchDescriptor<Item>())
        let songs = try context.fetch(FetchDescriptor<LibrarySongRecord>())

        #expect(items.count == 1)
        #expect(items[0].timestamp == timestamp)
        #expect(songs.isEmpty)
    }

    @Test func migratesPopulatedV1StoreWithoutLosingItemsOrSongs() throws {
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
        let timestamp = Date(timeIntervalSince1970: 2_345_678)
        let songID = UUID()

        try createV1Store(
            at: storeURL,
            timestamp: timestamp,
            songID: songID
        )

        let migratedContainer = try ResonaModelContainer.make(storeURL: storeURL)
        let context = ModelContext(migratedContainer)
        let items = try context.fetch(FetchDescriptor<Item>())
        let songs = try context.fetch(FetchDescriptor<LibrarySongRecord>())
        let removals = try context.fetch(
            FetchDescriptor<LibrarySongRemovalRecord>()
        )

        #expect(items.count == 1)
        #expect(items[0].timestamp == timestamp)
        #expect(songs.count == 1)
        #expect(songs[0].id == songID)
        #expect(songs[0].title == "V1 Song")
        #expect(removals.isEmpty)
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

    private func createV0Store(
        at storeURL: URL,
        timestamp: Date
    ) throws {
        let schema = Schema(versionedSchema: ResonaSchemaV0.self)
        let configuration = ModelConfiguration(
            "Resona",
            schema: schema,
            url: storeURL
        )
        let container = try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
        let context = ModelContext(container)
        context.insert(Item(timestamp: timestamp))
        try context.save()
    }

    private func createV1Store(
        at storeURL: URL,
        timestamp: Date,
        songID: UUID
    ) throws {
        let schema = Schema(versionedSchema: ResonaSchemaV1.self)
        let configuration = ModelConfiguration(
            "Resona",
            schema: schema,
            url: storeURL
        )
        let container = try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
        let context = ModelContext(container)
        context.insert(Item(timestamp: timestamp))
        context.insert(
            LibrarySongRecord(
                id: songID,
                contentDigest: "v1-content",
                byteCount: 512,
                managedAudioFilename: "v1-song.m4a",
                title: "V1 Song",
                artist: "Artist",
                album: "Album",
                durationSeconds: 120,
                managedArtworkFilename: "v1-song.jpg"
            )
        )
        try context.save()
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
