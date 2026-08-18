import Foundation
import SwiftData

enum WorkoutMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [WorkoutSchemaV1.self, WorkoutSchemaV2.self] }

    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: WorkoutSchemaV1.self, toVersion: WorkoutSchemaV2.self)]
    }
}
