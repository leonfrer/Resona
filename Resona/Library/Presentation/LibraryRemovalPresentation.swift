import Foundation

nonisolated enum LibraryRemovalPresentation {
    static func confirmationTitle(songTitle: String) -> String {
        let title = userFacingSongTitle(songTitle)
        return String(
            localized: "Remove “\(title)”?",
            comment: "Title for confirming removal of one library song"
        )
    }

    static func confirmationMessage(
        songTitle: String,
        stopsPlayback: Bool
    ) -> String {
        let title = userFacingSongTitle(songTitle)
        if stopsPlayback {
            return String(
                localized: "Playback will stop. Resona will delete its managed audio and artwork for “\(title)”. The original file will not be changed.",
                comment: "Removal warning when the song is currently playing"
            )
        }
        return String(
            localized: "Resona will delete its managed audio and artwork for “\(title)”. The original file will not be changed.",
            comment: "Removal warning when another song is currently playing"
        )
    }

    static func feedbackTitle(_ feedback: LibraryRemovalFeedback) -> String {
        switch feedback {
        case .requestFailure:
            String(localized: "Song Couldn’t Be Removed")
        case .cleanupIssue:
            String(localized: "Cleanup Couldn’t Finish")
        }
    }

    static func feedbackMessage(_ feedback: LibraryRemovalFeedback) -> String {
        switch feedback {
        case let .requestFailure(failure):
            let title = userFacingSongTitle(failure.song.title)
            switch failure.reason {
            case .busy:
                return String(
                    localized: "Another library change is still finishing. Try removing “\(title)” again in a moment."
                )
            case .notAccepted:
                return String(
                    localized: "Resona couldn’t safely remove “\(title)”. The song remains in your library."
                )
            }
        case let .cleanupIssue(issue):
            let title = userFacingSongTitle(issue.title)
            return String(
                localized: "“\(title)” was removed from your library, but Resona couldn’t finish deleting its managed files. Try again."
            )
        }
    }

    private static func userFacingSongTitle(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return String(localized: "Unknown Title")
        }

        let filenameStem = URL(fileURLWithPath: trimmed)
            .deletingPathExtension()
            .lastPathComponent
        guard UUID(uuidString: trimmed) == nil,
              UUID(uuidString: filenameStem) == nil
        else {
            return String(localized: "Unknown Title")
        }
        return trimmed
    }
}
