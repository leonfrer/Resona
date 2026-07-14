nonisolated protocol LibraryRemovalReconciling: Sendable {
    func reconcile(
        using reservation: LibraryMutationReservation
    ) async throws -> [LibraryRemovalIssue]
}
