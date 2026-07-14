import Foundation

@MainActor
protocol PlaybackRemovalInvalidating: Sendable {
    func beginRemovalInvalidation(for songID: UUID) async throws
    func endRemovalInvalidation(for songID: UUID)
}
