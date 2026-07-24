import Foundation

struct WorkoutTemplate: Identifiable {
    let id = UUID()
    let name: String
    let exerciseNames: [String]

    static let all: [WorkoutTemplate] = [
        WorkoutTemplate(name: "Gym", exerciseNames: [
            "Bench DB Press",
            "Overhead Press",
            "Lat Pull",
            "Cable Triceps Pressdown"
        ])
    ]

    static func template(named name: String) -> WorkoutTemplate? {
        all.first { $0.name == name }
    }
}
