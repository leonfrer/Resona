import SwiftUI

private struct AudioImporterEnvironmentKey: EnvironmentKey {
    static let defaultValue: any AudioImporting = UnavailableAudioImporter()
}

extension EnvironmentValues {
    var audioImporter: any AudioImporting {
        get { self[AudioImporterEnvironmentKey.self] }
        set { self[AudioImporterEnvironmentKey.self] = newValue }
    }
}

private struct UnavailableAudioImporter: AudioImporting {
    func importFiles(
        at sourceURLs: [URL]
    ) async throws -> AsyncStream<ImportEvent> {
        throw AudioImporterEnvironmentError.notInstalled
    }

    func retryFile(at sourceURL: URL) async throws -> AsyncStream<ImportEvent> {
        throw AudioImporterEnvironmentError.notInstalled
    }

    func cancelActiveImport() async {}

    func reconcileLibrary() async throws {
        throw AudioImporterEnvironmentError.notInstalled
    }
}

private enum AudioImporterEnvironmentError: Error {
    case notInstalled
}
