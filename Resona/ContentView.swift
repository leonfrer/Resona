import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(PlaybackStore.self) private var playbackStore

    let initialImportSession: ImportSessionModel?

    init(initialImportSession: ImportSessionModel? = nil) {
        self.initialImportSession = initialImportSession
    }

    var body: some View {
        NavigationStack {
            LibraryView(initialImportSession: initialImportSession)
        }
        .task {
            await playbackStore.restore()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                playbackStore.synchronizePosition()
            } else {
                Task {
                    playbackStore.synchronizePosition()
                    await playbackStore.flushRestoration()
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    let store = LibraryStore(
        repository: ContentViewPreviewRepository(),
        initialState: .loaded([])
    )
    ContentView()
        .environment(store)
        .environment(PlaybackStore.preview())
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
    func beginRemoval(id: UUID) -> LibraryRemovalBeginning { .missing }
    func pendingRemovals() -> [LibrarySongRemoval] { [] }
    func finalizeRemoval(id: UUID) {}
}
#endif
