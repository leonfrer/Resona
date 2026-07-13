import Foundation
import Testing
@testable import Resona

struct ImportSourceAccessingTests {
    @Test func coordinatesLocalReadAndCopiesCompleteBytes() async throws {
        let directoryURL = FileManager.default.temporaryDirectory.appending(
            path: UUID().uuidString,
            directoryHint: .isDirectory
        )
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        let sourceURL = directoryURL.appending(path: "source.mp3")
        let stagingURL = directoryURL.appending(path: "staging.partial")
        let bytes = Data("coordinated source bytes".utf8)
        try bytes.write(to: sourceURL)

        let fingerprint = try await SecurityScopedImportSourceAccessor()
            .copyToStaging(
                from: sourceURL,
                to: stagingURL,
                fingerprinter: SHA256ContentFingerprinter()
            )

        #expect(fingerprint.byteCount == Int64(bytes.count))
        #expect(try Data(contentsOf: stagingURL) == bytes)
    }
}
