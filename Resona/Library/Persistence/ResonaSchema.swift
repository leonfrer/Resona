import Foundation
import SwiftData

enum ResonaSchema {
    static var current: Schema {
        Schema([LibrarySongRecord.self, LibrarySongRemovalRecord.self])
    }
}

enum ResonaModelContainer {
    static func make(
        isStoredInMemoryOnly: Bool = false,
        storeURL: URL? = nil
    ) throws -> ModelContainer {
        let schema = ResonaSchema.current
        let configuration: ModelConfiguration

        if let storeURL {
            configuration = ModelConfiguration(
                "Resona",
                schema: schema,
                url: storeURL
            )
        } else {
            configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: isStoredInMemoryOnly
            )
        }

        return try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
    }
}
