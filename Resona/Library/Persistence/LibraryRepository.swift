import Foundation

nonisolated protocol LibraryRepository: Sendable {
    func fetchSongs(locale: Locale) async throws -> [LibrarySong]
    func song(id: UUID) async throws -> LibrarySong?
    func resourceReferences() async throws -> LibraryResourceReferences
    func duplicateCandidates(
        matching fingerprint: ContentFingerprint
    ) async throws -> [LibraryDuplicateCandidate]
    func insert(_ draft: LibrarySongDraft) async throws
    func restore(_ draft: LibrarySongDraft) async throws
    func beginRemoval(id: UUID) async throws -> LibraryRemovalBeginning
    func pendingRemovals() async throws -> [LibrarySongRemoval]
    func finalizeRemoval(id: UUID) async throws
}

extension LibraryRepository {
    func song(id: UUID) async throws -> LibrarySong? {
        try await fetchSongs(locale: .autoupdatingCurrent).first { $0.id == id }
    }
}

nonisolated enum LibraryRepositoryError: Error, Equatable {
    case duplicateIdentity(UUID)
    case missingSong(UUID)
}
