import Foundation
@testable import Resona

nonisolated struct StubLibraryResourceResolver: LibraryResourceResolving {
    var audioURLs: [String: URL] = [:]
    var artworkURLs: [String: URL] = [:]

    func audioURL(for managedFilename: String) async -> URL? {
        audioURLs[managedFilename]
    }

    func artworkURL(for managedFilename: String) async -> URL? {
        artworkURLs[managedFilename]
    }
}
