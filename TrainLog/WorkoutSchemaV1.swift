import Foundation
import SwiftData

enum WorkoutSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [WorkoutSession.self, ExerciseSet.self] }

    // Named to match the current models' simple type names (just namespaced under
    // this enum) — SwiftData's lightweight migration correlates entities across
    // schema versions by simple type name, not by position in the migration plan.
    @Model
    final class WorkoutSession {
        var id: UUID
        var templateName: String
        var date: Date
        var cardioType: String
        var cardioDuration: String
        var cardioDistance: String

        @Relationship(deleteRule: .cascade, inverse: \ExerciseSet.session)
        var sets: [ExerciseSet] = []

        init(templateName: String, date: Date = Date()) {
            self.id = UUID()
            self.templateName = templateName
            self.date = date
            self.cardioType = ""
            self.cardioDuration = ""
            self.cardioDistance = ""
            self.sets = []
        }
    }

    @Model
    final class ExerciseSet {
        var id: UUID
        var exerciseName: String
        var weight: Double
        var reps: Int
        var session: WorkoutSession?

        init(exerciseName: String, weight: Double, reps: Int) {
            self.id = UUID()
            self.exerciseName = exerciseName
            self.weight = weight
            self.reps = reps
        }
    }
}
