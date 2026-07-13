import Foundation

nonisolated protocol ManagedMediaStoring: LibraryResourceResolving {
    func stagingURL(
        operationID: UUID,
        candidateID: UUID
    ) async throws -> URL

    func commitAudio(
        from stagingURL: URL,
        songID: UUID,
        fileExtension: String
    ) async throws -> String

    func commitArtwork(
        from stagingURL: URL,
        songID: UUID,
        fileExtension: String
    ) async throws -> String

    func contentsEqual(
        stagedURL: URL,
        managedAudioFilename: String
    ) async throws -> Bool

    func removeResources(
        audioFilename: String?,
        artworkFilename: String?
    ) async throws

    func removeStagingOperation(id: UUID) async throws

    func reconcile(references: LibraryResourceReferences) async throws
}

nonisolated enum ManagedMediaStoreError: Error, Equatable {
    case invalidManagedFilename(String)
    case invalidFileExtension(String)
    case invalidStagingURL
    case missingStagedFile
    case destinationAlreadyExists(String)
}
