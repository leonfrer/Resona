import Foundation
import Observation

nonisolated struct ImportSessionEntry: Equatable, Identifiable, Sendable {
    let id: Int
    let sourceURL: URL
    var result: ImportFileResult?

    var displayName: String {
        let name = sourceURL.lastPathComponent
        return name.isEmpty ? String(localized: "Selected File") : name
    }
}

nonisolated struct ImportSummary: Equatable, Sendable {
    var importedCount = 0
    var restoredCount = 0
    var alreadyImportedCount = 0
    var failedCount = 0
    var cancelledCount = 0
    var warningCount = 0
}

nonisolated enum ImportSessionPhase: Equatable, Sendable {
    case ready
    case importing
    case finished
}

@MainActor
@Observable
final class ImportSessionModel: Identifiable {
    let id: UUID
    private(set) var phase: ImportSessionPhase
    private(set) var progress: ImportProgress
    private(set) var entries: [ImportSessionEntry]
    private(set) var hasSessionError = false
    private(set) var isCancelling = false

    private let audioImporter: any AudioImporting
    private let libraryStore: LibraryStore

    init(
        sourceURLs: [URL],
        audioImporter: any AudioImporting,
        libraryStore: LibraryStore,
        id: UUID = UUID()
    ) {
        self.id = id
        self.audioImporter = audioImporter
        self.libraryStore = libraryStore
        phase = .ready
        progress = ImportProgress(
            completedFileCount: 0,
            totalFileCount: sourceURLs.count,
            currentSourceDisplayName: nil
        )
        entries = Self.makeEntries(for: sourceURLs)
    }

    var isActive: Bool {
        phase == .importing
    }

    var summary: ImportSummary {
        entries.reduce(into: ImportSummary()) { summary, entry in
            guard let outcome = entry.result?.outcome else {
                return
            }
            switch outcome {
            case .imported:
                summary.importedCount += 1
            case .restored:
                summary.restoredCount += 1
            case .alreadyImported:
                summary.alreadyImportedCount += 1
            case let .warning(_, warnings):
                summary.importedCount += 1
                summary.warningCount += warnings.count
            case .failed:
                summary.failedCount += 1
            case .cancelled:
                summary.cancelledCount += 1
            }
        }
    }

    var recoverySongID: UUID? {
        entries.reversed().lazy.compactMap {
            $0.result?.outcome.recoverySongID
        }.first
    }

    func start() async {
        guard phase == .ready else {
            return
        }
        await runImport(sourceURLs: entries.map(\.sourceURL), retryingEntryID: nil)
    }

    func importNewFiles(at sourceURLs: [URL]) async {
        guard !sourceURLs.isEmpty, !isActive else {
            return
        }
        entries = Self.makeEntries(for: sourceURLs)
        progress = ImportProgress(
            completedFileCount: 0,
            totalFileCount: sourceURLs.count,
            currentSourceDisplayName: nil
        )
        hasSessionError = false
        phase = .ready
        await start()
    }

    func retry(entryID: ImportSessionEntry.ID) async {
        guard !isActive,
              let index = entries.firstIndex(where: { $0.id == entryID }) else {
            return
        }
        entries[index].result = nil
        progress = ImportProgress(
            completedFileCount: 0,
            totalFileCount: 1,
            currentSourceDisplayName: entries[index].displayName
        )
        hasSessionError = false
        await runImport(
            sourceURLs: [entries[index].sourceURL],
            retryingEntryID: entryID
        )
    }

    func cancel() async {
        guard isActive, !isCancelling else {
            return
        }
        isCancelling = true
        await audioImporter.cancelActiveImport()
    }

    private func runImport(
        sourceURLs: [URL],
        retryingEntryID: ImportSessionEntry.ID?
    ) async {
        phase = .importing
        isCancelling = false
        var nextResultIndex = 0

        do {
            let stream: AsyncStream<ImportEvent>
            if let retryingEntryID,
               let entry = entries.first(where: { $0.id == retryingEntryID }) {
                stream = try await audioImporter.retryFile(at: entry.sourceURL)
            } else {
                stream = try await audioImporter.importFiles(at: sourceURLs)
            }

            for await event in stream {
                switch event {
                case let .progress(newProgress):
                    progress = newProgress
                case let .result(result):
                    if let retryingEntryID,
                       let index = entries.firstIndex(
                           where: { $0.id == retryingEntryID }
                       ) {
                        entries[index].result = result
                    } else if nextResultIndex < entries.count {
                        entries[nextResultIndex].result = result
                        nextResultIndex += 1
                    }

                    if result.outcome.committedSongID != nil {
                        await libraryStore.refresh()
                    }
                case .finished:
                    phase = .finished
                }
            }
            if phase == .importing {
                phase = .finished
            }
        } catch is CancellationError {
            phase = .finished
        } catch {
            hasSessionError = true
            phase = .finished
        }
        isCancelling = false
    }

    private static func makeEntries(for sourceURLs: [URL]) -> [ImportSessionEntry] {
        sourceURLs.enumerated().map { index, url in
            ImportSessionEntry(id: index, sourceURL: url, result: nil)
        }
    }
}

private extension ImportFileResult.Outcome {
    var committedSongID: UUID? {
        switch self {
        case let .imported(id), let .restored(id), let .warning(id, _):
            id
        case .alreadyImported, .failed, .cancelled:
            nil
        }
    }

    var recoverySongID: UUID? {
        switch self {
        case let .imported(id),
             let .restored(id),
             let .alreadyImported(id),
             let .warning(id, _):
            id
        case .failed, .cancelled:
            nil
        }
    }
}

extension ImportSessionModel {
    static func previewImporting() -> ImportSessionModel {
        let urls = [
            URL(filePath: "/preview/Aerial Lines.m4a"),
            URL(filePath: "/preview/Night Signal.mp3"),
            URL(filePath: "/preview/Field Notes.wav"),
        ]
        let model = previewModel(sourceURLs: urls)
        model.phase = .importing
        model.progress = ImportProgress(
            completedFileCount: 1,
            totalFileCount: 3,
            currentSourceDisplayName: "Night Signal.mp3"
        )
        return model
    }

    static func previewMixedResults() -> ImportSessionModel {
        let urls = [
            URL(filePath: "/preview/Imported.m4a"),
            URL(filePath: "/preview/Warning.mp3"),
            URL(filePath: "/preview/Already Imported.wav"),
            URL(filePath: "/preview/Failed.flac"),
            URL(filePath: "/preview/Cancelled.aiff"),
        ]
        let model = previewModel(sourceURLs: urls)
        model.phase = .finished
        model.progress = ImportProgress(
            completedFileCount: urls.count,
            totalFileCount: urls.count,
            currentSourceDisplayName: nil
        )
        let songID = UUID(
            uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)
        )
        model.entries[0].result = ImportFileResult(
            sourceDisplayName: urls[0].lastPathComponent,
            outcome: .imported(songID)
        )
        model.entries[1].result = ImportFileResult(
            sourceDisplayName: urls[1].lastPathComponent,
            outcome: .warning(songID, [.artworkUnreadable])
        )
        model.entries[2].result = ImportFileResult(
            sourceDisplayName: urls[2].lastPathComponent,
            outcome: .alreadyImported(songID)
        )
        model.entries[3].result = ImportFileResult(
            sourceDisplayName: urls[3].lastPathComponent,
            outcome: .failed(.unsupportedCodec)
        )
        model.entries[4].result = ImportFileResult(
            sourceDisplayName: urls[4].lastPathComponent,
            outcome: .cancelled
        )
        return model
    }

    private static func previewModel(
        sourceURLs: [URL]
    ) -> ImportSessionModel {
        let repository = ImportSessionPreviewRepository()
        let store = LibraryStore(
            repository: repository,
            initialState: .loaded([])
        )
        return ImportSessionModel(
            sourceURLs: sourceURLs,
            audioImporter: ImportSessionPreviewAudioImporter(),
            libraryStore: store
        )
    }
}

private actor ImportSessionPreviewRepository: LibraryRepository {
    func fetchSongs(locale: Locale) -> [LibrarySong] { [] }
    func resourceReferences() -> LibraryResourceReferences {
        LibraryResourceReferences()
    }
    func duplicateCandidates(
        matching fingerprint: ContentFingerprint
    ) -> [LibraryDuplicateCandidate] { [] }
    func insert(_ draft: LibrarySongDraft) {}
    func restore(_ draft: LibrarySongDraft) {}
}

private struct ImportSessionPreviewAudioImporter: AudioImporting {
    func importFiles(
        at sourceURLs: [URL]
    ) async throws -> AsyncStream<ImportEvent> {
        AsyncStream { $0.finish() }
    }

    func retryFile(at sourceURL: URL) async throws -> AsyncStream<ImportEvent> {
        AsyncStream { $0.finish() }
    }

    func cancelActiveImport() async {}
    func reconcileLibrary() async throws {}
}
