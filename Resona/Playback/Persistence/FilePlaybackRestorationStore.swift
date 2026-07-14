import Foundation

actor FilePlaybackRestorationStore: PlaybackRestoring {
    private let fileURL: URL

    init(fileURL: URL) {
        self.fileURL = fileURL
    }

    static func applicationSupport() throws -> FilePlaybackRestorationStore {
        guard let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        return FilePlaybackRestorationStore(
            fileURL: applicationSupport
                .appending(path: "Resona", directoryHint: .isDirectory)
                .appending(path: "Playback", directoryHint: .isDirectory)
                .appending(path: "restoration.json", directoryHint: .notDirectory)
        )
    }

    func load() throws -> PlaybackRestorationSnapshot? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        let snapshot = try JSONDecoder().decode(
            PlaybackRestorationSnapshot.self,
            from: Data(contentsOf: fileURL)
        )
        guard snapshot.version == PlaybackRestorationSnapshot.currentVersion else {
            try clear()
            return nil
        }
        return snapshot
    }

    func save(_ snapshot: PlaybackRestorationSnapshot) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try JSONEncoder().encode(snapshot).write(to: fileURL, options: .atomic)
    }

    func clear() throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return
        }
        try FileManager.default.removeItem(at: fileURL)
    }
}
