import Foundation

nonisolated protocol LibraryRemoving: Sendable {
    func remove(
        id: UUID,
        beforeRemoval: @Sendable () async throws -> Void,
        afterAcceptance: @Sendable () async -> Void
    ) async -> LibraryRemovalOutcome

    func retryRemoval(id: UUID) async -> LibraryRemovalRetryOutcome
}
