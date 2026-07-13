import Foundation

nonisolated struct ContentFingerprint: Equatable, Sendable {
    let digest: String
    let byteCount: Int64

    init(digest: String, byteCount: Int64) {
        self.digest = digest.lowercased()
        self.byteCount = byteCount
    }
}
