import Foundation

nonisolated protocol AudioImporting: Sendable {
    func importFiles(at sourceURLs: [URL]) async throws -> AsyncStream<ImportEvent>
    func retryFile(at sourceURL: URL) async throws -> AsyncStream<ImportEvent>
    func cancelActiveImport() async
    func reconcileLibrary() async throws
}

extension AudioImportService: AudioImporting {}
