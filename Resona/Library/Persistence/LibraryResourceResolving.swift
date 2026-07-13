import Foundation

nonisolated protocol LibraryResourceResolving: Sendable {
    func audioURL(for managedFilename: String) async -> URL?
    func artworkURL(for managedFilename: String) async -> URL?
}

nonisolated struct UnavailableLibraryResourceResolver: LibraryResourceResolving {
    func audioURL(for managedFilename: String) async -> URL? {
        nil
    }

    func artworkURL(for managedFilename: String) async -> URL? {
        nil
    }
}
