import SwiftUI

struct ContentView: View {
    let initialImportSession: ImportSessionModel?

    init(initialImportSession: ImportSessionModel? = nil) {
        self.initialImportSession = initialImportSession
    }

    var body: some View {
        NavigationStack {
            LibraryView(initialImportSession: initialImportSession)
        }
    }
}

#Preview {
    let store = LibraryStore(
        repository: ContentViewPreviewRepository(),
        initialState: .loaded([])
    )
    ContentView()
        .environment(store)
}

private actor ContentViewPreviewRepository: LibraryRepository {
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
