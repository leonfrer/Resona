import Foundation

nonisolated enum SongAvailability: Equatable, Sendable {
    case available(audioURL: URL)
    case unavailable
}
