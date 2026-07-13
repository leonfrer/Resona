import CryptoKit
import Foundation

nonisolated protocol ContentFingerprinting: Sendable {
    func copyAndFingerprint(
        from sourceURL: URL,
        to destinationURL: URL
    ) throws -> ContentFingerprint
}

nonisolated struct SHA256ContentFingerprinter: ContentFingerprinting {
    private static let chunkSize = 64 * 1_024

    func copyAndFingerprint(
        from sourceURL: URL,
        to destinationURL: URL
    ) throws -> ContentFingerprint {
        let sourceHandle = try FileHandle(forReadingFrom: sourceURL)
        guard FileManager.default.createFile(
            atPath: destinationURL.path,
            contents: nil
        ) else {
            try? sourceHandle.close()
            throw CocoaError(.fileWriteUnknown)
        }
        let destinationHandle = try FileHandle(forWritingTo: destinationURL)
        defer {
            try? sourceHandle.close()
            try? destinationHandle.close()
        }

        var hasher = SHA256()
        var byteCount: Int64 = 0
        while true {
            try Task.checkCancellation()
            guard let data = try sourceHandle.read(upToCount: Self.chunkSize),
                  !data.isEmpty else {
                break
            }
            try destinationHandle.write(contentsOf: data)
            hasher.update(data: data)
            byteCount += Int64(data.count)
        }
        try destinationHandle.synchronize()

        let digest = hasher.finalize().map {
            String(format: "%02x", $0)
        }.joined()
        return ContentFingerprint(digest: digest, byteCount: byteCount)
    }
}
