import Foundation

nonisolated protocol PlaybackItemProviding: Sendable {
    func item(for songID: UUID) async throws -> PlaybackItem?
    func items(for songIDs: [UUID]) async throws -> [PlaybackItem]
}

extension PlaybackItemProviding {
    func items(for songIDs: [UUID]) async throws -> [PlaybackItem] {
        var resolvedItems: [PlaybackItem] = []
        resolvedItems.reserveCapacity(songIDs.count)
        for songID in songIDs {
            if let item = try await item(for: songID) {
                resolvedItems.append(item)
            }
        }
        return resolvedItems
    }
}
