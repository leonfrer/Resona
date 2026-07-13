import Foundation

nonisolated enum LibrarySongSorting {
    static func sorted(
        _ songs: [LibrarySong],
        locale: Locale = .current
    ) -> [LibrarySong] {
        songs.sorted { lhs, rhs in
            let titleOrder = lhs.title.compare(
                rhs.title,
                options: [.caseInsensitive, .diacriticInsensitive, .numeric],
                range: nil,
                locale: locale
            )

            switch titleOrder {
            case .orderedAscending:
                return true
            case .orderedDescending:
                return false
            case .orderedSame:
                return lhs.id.uuidString < rhs.id.uuidString
            }
        }
    }
}
