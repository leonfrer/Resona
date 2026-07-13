import Foundation
import Testing
@testable import Resona

struct ManagedMediaStoreTests {
    @Test func stagesAndAtomicallyCommitsCanonicalResources() async throws {
        let rootURL = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let store = ManagedMediaStore(rootURL: rootURL)
        let operationID = UUID()
        let songID = UUID()
        let audioStagingURL = try await store.stagingURL(
            operationID: operationID,
            candidateID: UUID()
        )
        let artworkStagingURL = try await store.stagingURL(
            operationID: operationID,
            candidateID: UUID()
        )
        try Data("complete audio".utf8).write(to: audioStagingURL)
        try Data("artwork".utf8).write(to: artworkStagingURL)

        let audioFilename = try await store.commitAudio(
            from: audioStagingURL,
            songID: songID,
            fileExtension: "M4A"
        )
        let artworkFilename = try await store.commitArtwork(
            from: artworkStagingURL,
            songID: songID,
            fileExtension: "JpG"
        )

        #expect(audioFilename == "\(songID.uuidString).m4a")
        #expect(artworkFilename == "\(songID.uuidString).jpg")
        #expect(await store.audioURL(for: audioFilename) != nil)
        #expect(await store.artworkURL(for: artworkFilename) != nil)
        #expect(!FileManager.default.fileExists(atPath: audioStagingURL.path))
        #expect(!FileManager.default.fileExists(atPath: artworkStagingURL.path))

        try await store.removeStagingOperation(id: operationID)
        let operationURL = rootURL
            .appending(path: "Staging", directoryHint: .isDirectory)
            .appending(path: operationID.uuidString, directoryHint: .isDirectory)
        #expect(!FileManager.default.fileExists(atPath: operationURL.path))
    }

    @Test func comparesCompleteManagedAudioBytes() async throws {
        let rootURL = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let store = ManagedMediaStore(rootURL: rootURL)
        let operationID = UUID()
        let original = Data(repeating: 0x2A, count: 150_000)
        let committedStagingURL = try await stagedFile(
            data: original,
            store: store,
            operationID: operationID
        )
        let audioFilename = try await store.commitAudio(
            from: committedStagingURL,
            songID: UUID(),
            fileExtension: "wav"
        )
        let matchingURL = try await stagedFile(
            data: original,
            store: store,
            operationID: operationID
        )
        var changed = original
        changed[changed.startIndex + 100_000] = 0x7F
        let changedURL = try await stagedFile(
            data: changed,
            store: store,
            operationID: operationID
        )
        let shorterURL = try await stagedFile(
            data: Data(original.dropLast()),
            store: store,
            operationID: operationID
        )

        #expect(
            try await store.contentsEqual(
                stagedURL: matchingURL,
                managedAudioFilename: audioFilename
            )
        )
        #expect(
            try await !store.contentsEqual(
                stagedURL: changedURL,
                managedAudioFilename: audioFilename
            )
        )
        #expect(
            try await !store.contentsEqual(
                stagedURL: shorterURL,
                managedAudioFilename: audioFilename
            )
        )
        #expect(
            try await !store.contentsEqual(
                stagedURL: matchingURL,
                managedAudioFilename: "missing.wav"
            )
        )
    }

    @Test func reconciliationPreservesReferencesAndRemovesAbandonedWork() async throws {
        let rootURL = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let store = ManagedMediaStore(rootURL: rootURL)
        let abandonedOperationID = UUID()
        let referencedAudio = try await committedResource(
            data: Data("referenced audio".utf8),
            kind: .audio,
            store: store,
            operationID: UUID(),
            songID: UUID(),
            fileExtension: "mp3"
        )
        let orphanedAudio = try await committedResource(
            data: Data("orphaned audio".utf8),
            kind: .audio,
            store: store,
            operationID: UUID(),
            songID: UUID(),
            fileExtension: "m4a"
        )
        let referencedArtwork = try await committedResource(
            data: Data("referenced artwork".utf8),
            kind: .artwork,
            store: store,
            operationID: UUID(),
            songID: UUID(),
            fileExtension: "png"
        )
        let orphanedArtwork = try await committedResource(
            data: Data("orphaned artwork".utf8),
            kind: .artwork,
            store: store,
            operationID: UUID(),
            songID: UUID(),
            fileExtension: "jpg"
        )
        let partialURL = try await store.stagingURL(
            operationID: abandonedOperationID,
            candidateID: UUID()
        )
        try Data("partial".utf8).write(to: partialURL)
        let invalidReferencedURL = rootURL
            .appending(path: "Audio", directoryHint: .isDirectory)
            .appending(path: "invalid.mp3", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: invalidReferencedURL,
            withIntermediateDirectories: true
        )

        try await store.reconcile(
            references: LibraryResourceReferences(
                audioFilenames: [referencedAudio, "invalid.mp3"],
                artworkFilenames: [referencedArtwork]
            )
        )

        #expect(await store.audioURL(for: referencedAudio) != nil)
        #expect(await store.audioURL(for: orphanedAudio) == nil)
        #expect(await store.artworkURL(for: referencedArtwork) != nil)
        #expect(await store.artworkURL(for: orphanedArtwork) == nil)
        #expect(!FileManager.default.fileExists(atPath: partialURL.path))
        #expect(!FileManager.default.fileExists(atPath: invalidReferencedURL.path))
    }

    @Test func cleanupIsIdempotentAndRejectsUnsafeFilenames() async throws {
        let rootURL = temporaryRoot()
        let parentURL = rootURL.deletingLastPathComponent()
        let outsideURL = parentURL.appending(path: "outside-\(UUID().uuidString)")
        defer {
            try? FileManager.default.removeItem(at: rootURL)
            try? FileManager.default.removeItem(at: outsideURL)
        }
        try Data("outside".utf8).write(to: outsideURL)
        let store = ManagedMediaStore(rootURL: rootURL)
        let audioFilename = try await committedResource(
            data: Data("audio".utf8),
            kind: .audio,
            store: store,
            operationID: UUID(),
            songID: UUID(),
            fileExtension: "aiff"
        )

        try await store.removeResources(
            audioFilename: audioFilename,
            artworkFilename: nil
        )
        try await store.removeResources(
            audioFilename: audioFilename,
            artworkFilename: nil
        )
        #expect(await store.audioURL(for: audioFilename) == nil)

        let unsafeFilename = "../\(outsideURL.lastPathComponent)"
        do {
            try await store.removeResources(
                audioFilename: unsafeFilename,
                artworkFilename: nil
            )
            Issue.record("Expected an invalid managed filename error")
        } catch let error as ManagedMediaStoreError {
            #expect(error == .invalidManagedFilename(unsafeFilename))
        }
        #expect(FileManager.default.fileExists(atPath: outsideURL.path))
        #expect(await store.audioURL(for: unsafeFilename) == nil)
    }

    @Test func failedCommitLeavesStagingForExplicitCleanup() async throws {
        let rootURL = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let store = ManagedMediaStore(rootURL: rootURL)
        let operationID = UUID()
        let songID = UUID()
        let firstURL = try await stagedFile(
            data: Data("first".utf8),
            store: store,
            operationID: operationID
        )
        _ = try await store.commitAudio(
            from: firstURL,
            songID: songID,
            fileExtension: "mp3"
        )
        let secondURL = try await stagedFile(
            data: Data("second".utf8),
            store: store,
            operationID: operationID
        )

        do {
            _ = try await store.commitAudio(
                from: secondURL,
                songID: songID,
                fileExtension: "mp3"
            )
            Issue.record("Expected a destination conflict")
        } catch let error as ManagedMediaStoreError {
            #expect(
                error == .destinationAlreadyExists("\(songID.uuidString).mp3")
            )
        }
        #expect(FileManager.default.fileExists(atPath: secondURL.path))

        try await store.removeStagingOperation(id: operationID)
        #expect(!FileManager.default.fileExists(atPath: secondURL.path))
    }

    @Test func rejectsInvalidExtensionAndNonStagingSource() async throws {
        let rootURL = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let store = ManagedMediaStore(rootURL: rootURL)
        let stagingURL = try await stagedFile(
            data: Data("audio".utf8),
            store: store,
            operationID: UUID()
        )

        do {
            _ = try await store.commitAudio(
                from: stagingURL,
                songID: UUID(),
                fileExtension: "../mp3"
            )
            Issue.record("Expected an invalid extension error")
        } catch let error as ManagedMediaStoreError {
            #expect(error == .invalidFileExtension("../mp3"))
        }
        #expect(FileManager.default.fileExists(atPath: stagingURL.path))

        let outsideURL = rootURL.appending(path: "outside.partial")
        try Data("outside".utf8).write(to: outsideURL)
        do {
            _ = try await store.commitAudio(
                from: outsideURL,
                songID: UUID(),
                fileExtension: "mp3"
            )
            Issue.record("Expected a missing staged file error")
        } catch let error as ManagedMediaStoreError {
            #expect(error == .missingStagedFile)
        }
    }

    private enum ResourceKind {
        case audio
        case artwork
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
    }

    private func stagedFile(
        data: Data,
        store: ManagedMediaStore,
        operationID: UUID
    ) async throws -> URL {
        let url = try await store.stagingURL(
            operationID: operationID,
            candidateID: UUID()
        )
        try data.write(to: url)
        return url
    }

    private func committedResource(
        data: Data,
        kind: ResourceKind,
        store: ManagedMediaStore,
        operationID: UUID,
        songID: UUID,
        fileExtension: String
    ) async throws -> String {
        let stagingURL = try await stagedFile(
            data: data,
            store: store,
            operationID: operationID
        )
        switch kind {
        case .audio:
            return try await store.commitAudio(
                from: stagingURL,
                songID: songID,
                fileExtension: fileExtension
            )
        case .artwork:
            return try await store.commitArtwork(
                from: stagingURL,
                songID: songID,
                fileExtension: fileExtension
            )
        }
    }
}
