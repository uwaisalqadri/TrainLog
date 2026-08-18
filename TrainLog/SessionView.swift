import SwiftUI
import SwiftData

struct SessionView: View {
    @Bindable var session: WorkoutSession
    @Environment(\.modelContext) private var modelContext
    @State private var copiedFeedback = false
    @State private var addedExerciseNames: [String] = []
    @State private var newExerciseName = ""

    private var exerciseNames: [String] {
        let templateNames = WorkoutTemplate.template(named: session.templateName)?.exerciseNames ?? []
        var combined = templateNames
        let loggedNames = session.sets.map(\.exerciseName).sorted()
        for name in loggedNames + addedExerciseNames where !combined.contains(name) {
            combined.append(name)
        }
        return combined
    }

    var body: some View {
        Form {
            Section("Date") {
                DatePicker("Date", selection: $session.date, displayedComponents: .date)
//                TextField("Workout Name (optional)", text: $session.customName)
            }

            ForEach(exerciseNames, id: \.self) { name in
                ExerciseSection(
                    exerciseName: name,
                    sets: session.sets.filter { $0.exerciseName == name },
                    onAdd: { weight, reps in
                        let set = ExerciseSet(exerciseName: name, weight: weight, reps: reps)
                        set.session = session
                        session.sets.append(set)
                        persist()
                    },
                    onDelete: { set in
                        session.sets.removeAll { $0.id == set.id }
                        modelContext.delete(set)
                    }
                )
            }

            Section("Add Exercise") {
                HStack {
                    TextField("Exercise name", text: $newExerciseName)
                    Button("Add") {
                        let name = newExerciseName.trimmingCharacters(in: .whitespaces)
                        guard !name.isEmpty, !exerciseNames.contains(name) else { return }
                        addedExerciseNames.append(name)
                        newExerciseName = ""
                    }
                    .disabled(newExerciseName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Section("Cardio") {
                TextField("Type (e.g. Running)", text: $session.cardioType)
                TextField("Duration (e.g. 30 min)", text: $session.cardioDuration)
                TextField("Distance (e.g. 5km)", text: $session.cardioDistance)
            }
        }
        .navigationTitle(session.date.formatted(date: .abbreviated, time: .omitted))
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(copiedFeedback ? "Copied!" : "Copy") {
                    UIPasteboard.general.string = SessionTextFormatter.text(for: session)
                    persist()
                    copiedFeedback = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        copiedFeedback = false
                    }
                }
            }
        }
        .onAppear {
            UserDefaults.standard.set(session.id.uuidString, forKey: WorkoutSession.lastOpenedIDKey)
        }
        .onDisappear {
            persist()
            UserDefaults.standard.removeObject(forKey: WorkoutSession.lastOpenedIDKey)
        }
    }

    private func persist() {
        modelContext.insert(session)
        try? modelContext.save()
    }
}

private struct ExerciseSection: View {
    let exerciseName: String
    let sets: [ExerciseSet]
    let onAdd: (Double, Int) -> Void
    let onDelete: (ExerciseSet) -> Void

    @State private var weightText = ""
    @State private var repsText = ""

    var body: some View {
        Section(exerciseName) {
            ForEach(sets) { set in
                Text("\(SessionTextFormatter.formatWeight(set.weight))kg × \(set.reps) reps")
            }
            .onDelete { offsets in
                for index in offsets {
                    onDelete(sets[index])
                }
            }

            HStack {
                TextField("Weight (kg)", text: $weightText)
                    .keyboardType(.decimalPad)
                TextField("Reps", text: $repsText)
                    .keyboardType(.numberPad)
                Button("Add Set") {
                    guard let weight = parsedWeight, let reps = parsedReps else { return }
                    onAdd(weight, reps)
                    weightText = ""
                    repsText = ""
                }
                .disabled(!isValidInput)
            }
        }
    }

    private var parsedWeight: Double? {
        guard let weight = Double(weightText.replacingOccurrences(of: ",", with: ".")), weight > 0 else { return nil }
        return weight
    }

    private var parsedReps: Int? {
        guard let reps = Int(repsText), reps > 0 else { return nil }
        return reps
    }

    private var isValidInput: Bool {
        parsedWeight != nil && parsedReps != nil
    }
}

#Preview {
    let session = WorkoutSession(templateName: "Gym")
    return NavigationStack {
        SessionView(session: session)
    }
    .modelContainer(for: [WorkoutSession.self, ExerciseSet.self], inMemory: true)
}
