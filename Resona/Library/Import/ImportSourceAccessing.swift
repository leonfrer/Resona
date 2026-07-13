import Foundation

nonisolated protocol ImportSourceAccessing: Sendable {
    func copyToStaging(
        from sourceURL: URL,
        to stagingURL: URL,
        fingerprinter: any ContentFingerprinting
    ) async throws -> ContentFingerprint
}

nonisolated struct SecurityScopedImportSourceAccessor: ImportSourceAccessing {
    func copyToStaging(
        from sourceURL: URL,
        to stagingURL: URL,
        fingerprinter: any ContentFingerprinting
    ) async throws -> ContentFingerprint {
        try Task.checkCancellation()
        let didStartAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var operationResult: Result<ContentFingerprint, Error>?
        coordinator.coordinate(
            readingItemAt: sourceURL,
            options: .withoutChanges,
            error: &coordinationError
        ) { coordinatedURL in
            operationResult = Result {
                try fingerprinter.copyAndFingerprint(
                    from: coordinatedURL,
                    to: stagingURL
                )
            }
        }

        if let coordinationError {
            throw coordinationError
        }
        guard let operationResult else {
            throw CocoaError(.fileReadUnknown)
        }
        return try operationResult.get()
    }
}
