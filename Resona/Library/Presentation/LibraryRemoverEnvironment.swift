import SwiftUI

private struct LibraryRemoverEnvironmentKey: EnvironmentKey {
    static let defaultValue: any LibraryRemoving = UnavailableLibraryRemover()
}

extension EnvironmentValues {
    var libraryRemover: any LibraryRemoving {
        get { self[LibraryRemoverEnvironmentKey.self] }
        set { self[LibraryRemoverEnvironmentKey.self] = newValue }
    }
}

private struct UnavailableLibraryRemover: LibraryRemoving {
    func remove(
        id: UUID,
        beforeRemoval: @Sendable () async throws -> Void,
        afterAcceptance: @Sendable () async -> Void
    ) async -> LibraryRemovalOutcome {
        .notAccepted
    }

    func retryRemoval(id: UUID) async -> LibraryRemovalRetryOutcome {
        .failed
    }
}
