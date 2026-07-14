import Foundation

nonisolated struct LibraryRemovalIssue: Equatable, Identifiable, Sendable {
    let id: UUID
    let title: String
}

nonisolated enum LibraryRemovalOutcome: Equatable, Sendable {
    case removed
    case pendingCleanup(LibraryRemovalIssue)
    case missing
    case busy
    case notAccepted
}

nonisolated enum LibraryRemovalRetryOutcome: Equatable, Sendable {
    case completed
    case pendingCleanup(LibraryRemovalIssue)
    case missing
    case busy
    case failed
}

nonisolated enum LibraryRemovalReconciliationError: Error, Equatable {
    case persistenceFailed
    case managedStorageFailed
}
