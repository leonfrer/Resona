import Foundation
import Testing
@testable import Resona

struct ContentFingerprintingTests {
    @Test func fingerprintsCompleteBytesWhileCopying() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let sourceURL = directory.appending(path: "source")
        let destinationURL = directory.appending(path: "destination")
        try Data("abc".utf8).write(to: sourceURL)

        let fingerprint = try SHA256ContentFingerprinter().copyAndFingerprint(
            from: sourceURL,
            to: destinationURL
        )

        #expect(
            fingerprint.digest
                == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
        #expect(fingerprint.byteCount == 3)
        #expect(try Data(contentsOf: destinationURL) == Data("abc".utf8))
    }

    @Test func changedBytesProduceDifferentEvidence() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let firstURL = directory.appending(path: "first")
        let secondURL = directory.appending(path: "second")
        try Data("same length A".utf8).write(to: firstURL)
        try Data("same length B".utf8).write(to: secondURL)
        let fingerprinter = SHA256ContentFingerprinter()

        let first = try fingerprinter.copyAndFingerprint(
            from: firstURL,
            to: directory.appending(path: "first-copy")
        )
        let second = try fingerprinter.copyAndFingerprint(
            from: secondURL,
            to: directory.appending(path: "second-copy")
        )

        #expect(first.byteCount == second.byteCount)
        #expect(first.digest != second.digest)
    }

    @Test func cancellationDoesNotReturnACompletedFingerprint() async throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let sourceURL = directory.appending(path: "large-source")
        let destinationURL = directory.appending(path: "partial")
        try Data(repeating: 0x2A, count: 128 * 1_024).write(to: sourceURL)

        let task = Task.detached {
            withUnsafeCurrentTask { task in
                task?.cancel()
            }
            return try SHA256ContentFingerprinter().copyAndFingerprint(
                from: sourceURL,
                to: destinationURL
            )
        }

        do {
            _ = try await task.value
            Issue.record("Expected fingerprinting to be cancelled")
        } catch is CancellationError {
            #expect(true)
        }
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory.appending(
            path: UUID().uuidString,
            directoryHint: .isDirectory
        )
    }
}
