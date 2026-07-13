import Foundation
import Testing
@testable import Resona

struct LibrarySongSortingTests {
    @Test func sortsTitlesNaturallyThenUsesStableIdentity() {
        let lowerID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let higherID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let songs = [
            song(id: higherID, title: "Track 2"),
            song(id: UUID(), title: "Track 10"),
            song(id: lowerID, title: "Track 2"),
            song(id: UUID(), title: "Álbum"),
        ]

        let sorted = LibrarySongSorting.sorted(
            songs,
            locale: Locale(identifier: "en_US")
        )

        #expect(sorted.map(\.title) == ["Álbum", "Track 2", "Track 2", "Track 10"])
        #expect(sorted[1].id == lowerID)
        #expect(sorted[2].id == higherID)
    }

    private func song(id: UUID, title: String) -> LibrarySong {
        LibrarySong(
            id: id,
            title: title,
            artist: nil,
            album: nil,
            durationSeconds: nil,
            artworkURL: nil,
            availability: .unavailable
        )
    }
}
