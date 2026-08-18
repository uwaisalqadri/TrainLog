import XCTest
import SwiftData
@testable import TrainLog

final class MigrationTests: XCTestCase {
    func testMigratingFromV1PreservesExistingDataAndDefaultsNewField() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("store")
        defer {
            for suffix in ["", "-wal", "-shm"] {
                try? FileManager.default.removeItem(atPath: storeURL.path + suffix)
            }
        }

        // Write a store shaped like the old (V1) schema, before `customName` existed.
        let v1Schema = Schema(versionedSchema: WorkoutSchemaV1.self)
        let v1Config = ModelConfiguration(schema: v1Schema, url: storeURL)
        let v1Container = try ModelContainer(for: v1Schema, migrationPlan: nil, configurations: [v1Config])
        let v1Context = ModelContext(v1Container)

        let oldSession = WorkoutSchemaV1.WorkoutSession(templateName: "Gym")
        let oldSet = WorkoutSchemaV1.ExerciseSet(exerciseName: "Bench DB Press", weight: 17.5, reps: 10)
        oldSet.session = oldSession
        oldSession.sets.append(oldSet)
        v1Context.insert(oldSession)
        try v1Context.save()

        // Reopen the SAME store under the current schema, going through the real migration plan.
        let currentSchema = Schema([WorkoutSession.self, ExerciseSet.self])
        let v2Config = ModelConfiguration(schema: currentSchema, url: storeURL)
        let migratedContainer = try ModelContainer(
            for: currentSchema,
            migrationPlan: WorkoutMigrationPlan.self,
            configurations: [v2Config]
        )
        let migratedContext = ModelContext(migratedContainer)

        let migratedSessions = try migratedContext.fetch(FetchDescriptor<WorkoutSession>())
        XCTAssertEqual(migratedSessions.count, 1, "the pre-existing session must survive the migration")

        let migrated = try XCTUnwrap(migratedSessions.first)
        XCTAssertEqual(migrated.templateName, "Gym")
        XCTAssertEqual(migrated.customName, "", "new field should default rather than fail to load")
        XCTAssertEqual(migrated.sets.count, 1, "the pre-existing set must survive the migration")
        XCTAssertEqual(migrated.sets.first?.exerciseName, "Bench DB Press")
        XCTAssertEqual(migrated.sets.first?.weight, 17.5)
        XCTAssertEqual(migrated.sets.first?.reps, 10)
    }
}
