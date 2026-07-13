import Foundation

nonisolated protocol LibraryRepository: Sendable {
    func fetchSongs(locale: Locale) async throws -> [LibrarySong]
    func resourceReferences() async throws -> LibraryResourceReferences
    func duplicateCandidates(
        matching fingerprint: ContentFingerprint
    ) async throws -> [LibraryDuplicateCandidate]
    func insert(_ draft: LibrarySongDraft) async throws
    func restore(_ draft: LibrarySongDraft) async throws
}

nonisolated enum LibraryRepositoryError: Error, Equatable {
    case duplicateIdentity(UUID)
    case missingSong(UUID)
}
