import Foundation

nonisolated protocol PlaybackItemProviding: Sendable {
    func item(for songID: UUID) async throws -> PlaybackItem?
}
