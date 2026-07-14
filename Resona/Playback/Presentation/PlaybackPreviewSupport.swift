import SwiftUI

#if DEBUG
extension PlaybackItem {
    static var preview: PlaybackItem {
        PlaybackItem(
            id: UUID(
                uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)
            ),
            title: "Aerial Lines",
            artist: "Mira Chen",
            album: "Night Transit",
            artworkURL: nil,
            availability: .available(
                audioURL: URL(filePath: "/preview/aerial-lines.m4a")
            ),
            libraryDurationSeconds: 180
        )
    }
}

extension PlaybackStore {
    static func preview(
        item: PlaybackItem? = nil,
        phase: PlaybackPhase = .idle,
        position: TimeInterval = 0,
        duration: TimeInterval? = nil
    ) -> PlaybackStore {
        PlaybackStore(
            itemProvider: PlaybackPreviewItemProvider(),
            engine: PlaybackPreviewEngine(),
            audioSession: PlaybackPreviewAudioSession(),
            initialItem: item,
            initialPhase: phase,
            initialPosition: position,
            initialDuration: duration
        )
    }
}

extension View {
    func playbackPreviewEnvironment(
        item: PlaybackItem? = PlaybackItem.preview,
        phase: PlaybackPhase,
        position: TimeInterval = 0,
        duration: TimeInterval? = nil
    ) -> some View {
        let repository = PlaybackPreviewLibraryRepository()
        return environment(
            PlaybackStore.preview(
                item: item,
                phase: phase,
                position: position,
                duration: duration
            )
        )
        .environment(
            LibraryStore(
                repository: repository,
                initialState: .loaded([])
            )
        )
    }
}

nonisolated private struct PlaybackPreviewItemProvider: PlaybackItemProviding {
    func item(for songID: UUID) async throws -> PlaybackItem? {
        nil
    }
}

private final class PlaybackPreviewEngine: AudioPlaybackEngine {
    let events = AsyncStream<AudioPlaybackEvent> { _ in }

    func prepare(url: URL) throws -> AudioPlaybackPreparation {
        throw AudioPlaybackEngineError.resourceInvalid
    }
    func play(sessionID: UUID) throws {}
    func pause(sessionID: UUID) {}
    func seek(to seconds: TimeInterval, sessionID: UUID) {}
    func currentPosition(sessionID: UUID) -> TimeInterval? { nil }
    func stop() {}
}

private final class PlaybackPreviewAudioSession: AudioSessionControlling {
    let events = AsyncStream<AudioSessionEvent> { _ in }

    func activate() throws {}
    func deactivate() throws {}
}

private actor PlaybackPreviewLibraryRepository: LibraryRepository {
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
