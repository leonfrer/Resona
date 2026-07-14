import Foundation
import SwiftData

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

enum ResonaMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [ResonaSchemaV0.self, ResonaSchemaV1.self, ResonaSchemaV2.self]
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
        ]
    }
}

enum ResonaModelContainer {
    static func make(
        isStoredInMemoryOnly: Bool = false,
        storeURL: URL? = nil
    ) throws -> ModelContainer {
        let schema = Schema(versionedSchema: ResonaSchemaV2.self)
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
