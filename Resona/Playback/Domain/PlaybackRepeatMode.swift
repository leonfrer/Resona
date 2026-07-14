nonisolated enum PlaybackRepeatMode: String, CaseIterable, Codable, Sendable {
    case off
    case all
    case one

    mutating func cycle() {
        self = switch self {
        case .off:
            .all
        case .all:
            .one
        case .one:
            .off
        }
    }
}
