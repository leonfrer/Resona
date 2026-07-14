import Foundation

@MainActor
protocol PlaybackRemovalInvalidating: Sendable {
    func beginRemovalInvalidation(for songID: UUID) throws
    func endRemovalInvalidation(for songID: UUID)
}
