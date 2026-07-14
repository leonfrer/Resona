import Foundation

nonisolated struct LibraryRemovalRequestFailure: Equatable, Sendable {
    enum Reason: Equatable, Sendable {
        case busy
        case notAccepted
    }

    let song: LibrarySong
    let reason: Reason
}

nonisolated enum LibraryRemovalFeedback: Equatable, Identifiable, Sendable {
    enum ID: Hashable, Sendable {
        case request(UUID)
        case cleanup(UUID)
    }

    case requestFailure(LibraryRemovalRequestFailure)
    case cleanupIssue(LibraryRemovalIssue)

    var id: ID {
        switch self {
        case let .requestFailure(failure):
            .request(failure.song.id)
        case let .cleanupIssue(issue):
            .cleanup(issue.id)
        }
    }
}
