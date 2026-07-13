import Foundation

actor ManagedMediaStore: ManagedMediaStoring {
    private enum Directory {
        static let audio = "Audio"
        static let artwork = "Artwork"
        static let staging = "Staging"
    }

    private static let comparisonChunkSize = 64 * 1_024

    private let rootURL: URL
    private let fileManager: FileManager

    init(rootURL: URL, fileManager: FileManager = .default) {
        self.rootURL = rootURL.standardizedFileURL
        self.fileManager = fileManager
    }

    nonisolated static func applicationSupportRoot(
        fileManager: FileManager = .default
    ) throws -> URL {
        let applicationSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return applicationSupport
            .appending(path: "ManagedLibrary", directoryHint: .isDirectory)
            .appending(path: "v1", directoryHint: .isDirectory)
    }

    func stagingURL(operationID: UUID, candidateID: UUID) throws -> URL {
        try createManagedDirectories()
        let operationURL = stagingRootURL.appending(
            path: operationID.uuidString,
            directoryHint: .isDirectory
        )
        try fileManager.createDirectory(
            at: operationURL,
            withIntermediateDirectories: true
        )
        return operationURL.appending(
            path: "\(candidateID.uuidString).partial",
            directoryHint: .notDirectory
        )
    }

    func commitAudio(
        from stagingURL: URL,
        songID: UUID,
        fileExtension: String
    ) throws -> String {
        try commit(
            from: stagingURL,
            to: audioRootURL,
            songID: songID,
            fileExtension: fileExtension
        )
    }

    func commitArtwork(
        from stagingURL: URL,
        songID: UUID,
        fileExtension: String
    ) throws -> String {
        try commit(
            from: stagingURL,
            to: artworkRootURL,
            songID: songID,
            fileExtension: fileExtension
        )
    }

    func audioURL(for managedFilename: String) -> URL? {
        availableResourceURL(
            filename: managedFilename,
            directoryURL: audioRootURL
        )
    }

    func artworkURL(for managedFilename: String) -> URL? {
        availableResourceURL(
            filename: managedFilename,
            directoryURL: artworkRootURL
        )
    }

    func contentsEqual(
        stagedURL: URL,
        managedAudioFilename: String
    ) async throws -> Bool {
        guard isContainedInStaging(stagedURL),
              isRegularFile(at: stagedURL),
              let managedURL = audioURL(for: managedAudioFilename) else {
            return false
        }

        let stagedValues = try stagedURL.resourceValues(forKeys: [.fileSizeKey])
        let managedValues = try managedURL.resourceValues(forKeys: [.fileSizeKey])
        guard stagedValues.fileSize == managedValues.fileSize else {
            return false
        }

        let stagedHandle = try FileHandle(forReadingFrom: stagedURL)
        let managedHandle = try FileHandle(forReadingFrom: managedURL)
        defer {
            try? stagedHandle.close()
            try? managedHandle.close()
        }

        while true {
            try Task.checkCancellation()
            let stagedData = try stagedHandle.read(upToCount: Self.comparisonChunkSize)
            let managedData = try managedHandle.read(upToCount: Self.comparisonChunkSize)
            guard stagedData == managedData else {
                return false
            }
            if stagedData?.isEmpty != false {
                return true
            }
        }
    }

    func removeResources(
        audioFilename: String?,
        artworkFilename: String?
    ) throws {
        if let audioFilename {
            try removeResource(
                filename: audioFilename,
                directoryURL: audioRootURL
            )
        }
        if let artworkFilename {
            try removeResource(
                filename: artworkFilename,
                directoryURL: artworkRootURL
            )
        }
    }

    func removeStagingOperation(id: UUID) throws {
        let operationURL = stagingRootURL.appending(
            path: id.uuidString,
            directoryHint: .isDirectory
        )
        try removeIfPresent(at: operationURL)
    }

    func reconcile(references: LibraryResourceReferences) throws {
        try createManagedDirectories()
        try removeContents(of: stagingRootURL, preserving: [])
        try removeContents(
            of: audioRootURL,
            preserving: validFilenames(in: references.audioFilenames)
        )
        try removeContents(
            of: artworkRootURL,
            preserving: validFilenames(in: references.artworkFilenames)
        )
    }

    private var audioRootURL: URL {
        rootURL.appending(path: Directory.audio, directoryHint: .isDirectory)
    }

    private var artworkRootURL: URL {
        rootURL.appending(path: Directory.artwork, directoryHint: .isDirectory)
    }

    private var stagingRootURL: URL {
        rootURL.appending(path: Directory.staging, directoryHint: .isDirectory)
    }

    private func createManagedDirectories() throws {
        for directoryURL in [audioRootURL, artworkRootURL, stagingRootURL] {
            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
        }
    }

    private func commit(
        from stagingURL: URL,
        to directoryURL: URL,
        songID: UUID,
        fileExtension: String
    ) throws -> String {
        try createManagedDirectories()
        guard isContainedInStaging(stagingURL), isRegularFile(at: stagingURL) else {
            throw ManagedMediaStoreError.missingStagedFile
        }
        let canonicalExtension = try canonicalFileExtension(fileExtension)
        let filename = "\(songID.uuidString).\(canonicalExtension)"
        let destinationURL = directoryURL.appending(
            path: filename,
            directoryHint: .notDirectory
        )
        guard !fileManager.fileExists(atPath: destinationURL.path) else {
            throw ManagedMediaStoreError.destinationAlreadyExists(filename)
        }

        try fileManager.moveItem(at: stagingURL, to: destinationURL)
        return filename
    }

    private func availableResourceURL(
        filename: String,
        directoryURL: URL
    ) -> URL? {
        guard isValidManagedFilename(filename) else {
            return nil
        }
        let resourceURL = directoryURL.appending(
            path: filename,
            directoryHint: .notDirectory
        )
        return isRegularFile(at: resourceURL) ? resourceURL : nil
    }

    private func removeResource(filename: String, directoryURL: URL) throws {
        guard isValidManagedFilename(filename) else {
            throw ManagedMediaStoreError.invalidManagedFilename(filename)
        }
        try removeIfPresent(
            at: directoryURL.appending(
                path: filename,
                directoryHint: .notDirectory
            )
        )
    }

    private func removeContents(
        of directoryURL: URL,
        preserving filenames: Set<String>
    ) throws {
        let contents = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: []
        )
        for url in contents {
            let isReferencedRegularFile = filenames.contains(url.lastPathComponent)
                && isRegularFile(at: url)
            if !isReferencedRegularFile {
                try fileManager.removeItem(at: url)
            }
        }
    }

    private func removeIfPresent(at url: URL) throws {
        do {
            try fileManager.removeItem(at: url)
        } catch let error as CocoaError where error.code == .fileNoSuchFile {
            // Cleanup is intentionally idempotent.
        }
    }

    private func isContainedInStaging(_ url: URL) -> Bool {
        let stagingPath = stagingRootURL.standardizedFileURL.path
        let candidatePath = url.standardizedFileURL.path
        return candidatePath.hasPrefix(stagingPath + "/")
    }

    private func isRegularFile(at url: URL) -> Bool {
        guard let values = try? url.resourceValues(
            forKeys: [.isRegularFileKey, .isSymbolicLinkKey]
        ) else {
            return false
        }
        return values.isRegularFile == true && values.isSymbolicLink != true
    }

    private func canonicalFileExtension(_ fileExtension: String) throws -> String {
        let canonical = fileExtension.lowercased()
        let allowed = canonical.unicodeScalars.allSatisfy {
            CharacterSet.alphanumerics.contains($0)
        }
        guard !canonical.isEmpty, allowed else {
            throw ManagedMediaStoreError.invalidFileExtension(fileExtension)
        }
        return canonical
    }

    private func validFilenames(in filenames: Set<String>) -> Set<String> {
        Set(filenames.filter(isValidManagedFilename))
    }

    private func isValidManagedFilename(_ filename: String) -> Bool {
        !filename.isEmpty
            && filename != "."
            && filename != ".."
            && !filename.contains("/")
            && !filename.contains("\\")
            && URL(fileURLWithPath: filename).lastPathComponent == filename
    }
}
