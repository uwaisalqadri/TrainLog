import Foundation
import SwiftData

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
