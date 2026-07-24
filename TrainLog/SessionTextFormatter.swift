import Foundation

enum SessionTextFormatter {
    static func text(for session: WorkoutSession) -> String {
        var lines: [String] = []
        let dateString = session.date.formatted(.dateTime.month(.abbreviated).day())
        lines.append("🏋️ \(session.templateName) – \(dateString)")
        lines.append("")

        if let highest = session.sets.map(\.weight).max() {
            lines.append("Highest Weight: \(formatWeight(highest)) kg")
            lines.append("")
        }

        lines.append("Exercises:")
        let exerciseNames = WorkoutTemplate.template(named: session.templateName)?.exerciseNames ?? []
        for name in exerciseNames {
            let sets = session.sets.filter { $0.exerciseName == name }
            guard !sets.isEmpty else { continue }
            lines.append("- \(name) — \(groupedSetsText(sets))")
        }
        lines.append("")

        lines.append("Cardio:")
        lines.append("- \(cardioText(for: session))")

        return lines.joined(separator: "\n")
    }

    static func groupedSetsText(_ sets: [ExerciseSet]) -> String {
        struct Key: Hashable { let weight: Double; let reps: Int }
        var order: [Key] = []
        var counts: [Key: Int] = [:]
        for set in sets {
            let key = Key(weight: set.weight, reps: set.reps)
            if counts[key] == nil { order.append(key) }
            counts[key, default: 0] += 1
        }
        return order.map { key -> String in
            let count = counts[key]!
            let base = "\(formatWeight(key.weight))kg x\(key.reps)"
            return count > 1 ? "\(base) (x\(count) sets)" : base
        }.joined(separator: ", ")
    }

    static func cardioText(for session: WorkoutSession) -> String {
        let parts = [session.cardioType, session.cardioDuration, session.cardioDistance]
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return parts.isEmpty ? "No" : parts.joined(separator: " - ")
    }

    static func formatWeight(_ weight: Double) -> String {
        weight.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(weight))
            : String(weight)
    }

    #if DEBUG
    static func runSelfTest() {
        let session = WorkoutSession(templateName: "Gym", date: Date())
        let s1 = ExerciseSet(exerciseName: "Bench DB Press", weight: 17.5, reps: 10)
        let s2 = ExerciseSet(exerciseName: "Bench DB Press", weight: 17.5, reps: 10)
        let s3 = ExerciseSet(exerciseName: "Bench DB Press", weight: 20, reps: 8)
        session.sets = [s1, s2, s3]

        let grouped = groupedSetsText(session.sets.filter { $0.exerciseName == "Bench DB Press" })
        assert(grouped == "17.5kg x10 (x2 sets), 20kg x8", "grouping failed: \(grouped)")

        let singleSetSession = WorkoutSession(templateName: "Gym", date: Date())
        let single = ExerciseSet(exerciseName: "Overhead Press", weight: 20, reps: 8)
        singleSetSession.sets = [single]
        let singleGrouped = groupedSetsText(singleSetSession.sets)
        assert(singleGrouped == "20kg x8", "singleton grouping failed: \(singleGrouped)")

        let emptySession = WorkoutSession(templateName: "Gym", date: Date())
        assert(emptySession.sets.map(\.weight).max() == nil, "empty session should have no max weight")
        assert(cardioText(for: emptySession) == "No", "empty cardio should render No")

        emptySession.cardioType = "Running"
        emptySession.cardioDuration = "30 min"
        assert(cardioText(for: emptySession) == "Running - 30 min", "cardio text failed: \(cardioText(for: emptySession))")

        // End-to-end test: text(for:) with fully-populated session
        var fixedDateComponents = DateComponents()
        fixedDateComponents.year = 2026
        fixedDateComponents.month = 7
        fixedDateComponents.day = 24
        fixedDateComponents.hour = 12
        fixedDateComponents.minute = 0
        let fixedDate = Calendar.current.date(from: fixedDateComponents)!

        let endToEndSession = WorkoutSession(templateName: "Gym", date: fixedDate)
        let e1 = ExerciseSet(exerciseName: "Bench DB Press", weight: 17.5, reps: 10)
        let e2 = ExerciseSet(exerciseName: "Bench DB Press", weight: 17.5, reps: 10)
        let e3 = ExerciseSet(exerciseName: "Bench DB Press", weight: 20, reps: 8)
        let e4 = ExerciseSet(exerciseName: "Overhead Press", weight: 20, reps: 8)
        endToEndSession.sets = [e1, e2, e3, e4]
        // cardio fields left empty (default empty strings from init)

        let dateString = fixedDate.formatted(.dateTime.month(.abbreviated).day())
        let expected = "🏋️ Gym – \(dateString)\n\nHighest Weight: 20 kg\n\nExercises:\n- Bench DB Press — 17.5kg x10 (x2 sets), 20kg x8\n- Overhead Press — 20kg x8\n\nCardio:\n- No"

        let result = text(for: endToEndSession)
        assert(result == expected, "text(for:) end-to-end formatting failed:\nExpected:\n\(expected)\n\nGot:\n\(result)")

        print("SessionTextFormatter self-test passed")
    }
    #endif
}
