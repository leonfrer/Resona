import Foundation
import Testing
@testable import Resona

struct PlaybackRestorationStoreTests {
    @Test func fileStoreRoundTripsAndClearsSnapshot() async throws {
        let fileURL = temporaryFileURL()
        let store = FilePlaybackRestorationStore(fileURL: fileURL)
        let id = UUID()
        let snapshot = PlaybackRestorationSnapshot(
            baseOrder: [id],
            currentID: id,
            position: 12,
            repeatMode: .one,
            isShuffleEnabled: false,
            traversalOrder: [id],
            history: [id],
            historyIndex: 0
        )

        try await store.save(snapshot)
        #expect(try await store.load() == snapshot)

        try await store.clear()
        #expect(try await store.load() == nil)
    }

    @Test func fileStoreRejectsCorruptAndUnsupportedSnapshots() async throws {
        let corruptURL = temporaryFileURL()
        try FileManager.default.createDirectory(
            at: corruptURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("not-json".utf8).write(to: corruptURL)
        let corruptStore = FilePlaybackRestorationStore(fileURL: corruptURL)
        await #expect(throws: (any Error).self) {
            _ = try await corruptStore.load()
        }

        let unsupportedURL = temporaryFileURL()
        let unsupportedStore = FilePlaybackRestorationStore(fileURL: unsupportedURL)
        let id = UUID()
        try await unsupportedStore.save(
            PlaybackRestorationSnapshot(
                version: PlaybackRestorationSnapshot.currentVersion + 1,
                baseOrder: [id],
                currentID: id,
                position: 0,
                repeatMode: .off,
                isShuffleEnabled: false,
                traversalOrder: [id],
                history: [id],
                historyIndex: 0
            )
        )
        #expect(try await unsupportedStore.load() == nil)
        #expect(!FileManager.default.fileExists(atPath: unsupportedURL.path))
    }

    private func temporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "restoration.json", directoryHint: .notDirectory)
    }
}
