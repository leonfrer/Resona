import Foundation
import SwiftData

// Historical model retained only so V0, V1, and V2 stores can migrate.
@Model
final class Item {
    var timestamp: Date

    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}

enum ResonaSchemaV0: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Item.self]
    }
}

enum ResonaSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Item.self, LibrarySongRecord.self]
    }
}

enum ResonaSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Item.self, LibrarySongRecord.self, LibrarySongRemovalRecord.self]
    }
}

enum ResonaSchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(4, 0, 0)

    static var models: [any PersistentModel.Type] {
        [LibrarySongRecord.self, LibrarySongRemovalRecord.self]
    }
}

enum ResonaMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [
            ResonaSchemaV0.self,
            ResonaSchemaV1.self,
            ResonaSchemaV2.self,
            ResonaSchemaV3.self,
        ]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(
                fromVersion: ResonaSchemaV0.self,
                toVersion: ResonaSchemaV1.self
            ),
            .lightweight(
                fromVersion: ResonaSchemaV1.self,
                toVersion: ResonaSchemaV2.self
            ),
            .lightweight(
                fromVersion: ResonaSchemaV2.self,
                toVersion: ResonaSchemaV3.self
            ),
        ]
    }
}

enum ResonaModelContainer {
    static func make(
        isStoredInMemoryOnly: Bool = false,
        storeURL: URL? = nil
    ) throws -> ModelContainer {
        let schema = Schema(versionedSchema: ResonaSchemaV3.self)
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
            migrationPlan: ResonaMigrationPlan.self,
            configurations: [configuration]
        )
    }
}
