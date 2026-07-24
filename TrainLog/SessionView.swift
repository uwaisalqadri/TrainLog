import SwiftUI
import SwiftData

struct SessionView: View {
    @Bindable var session: WorkoutSession
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var copiedFeedback = false
    @State private var didSave = false

    private var exerciseNames: [String] {
        WorkoutTemplate.template(named: session.templateName)?.exerciseNames ?? []
    }

    var body: some View {
        Form {
            Section("Date") {
                DatePicker("Date", selection: $session.date, displayedComponents: .date)
            }

            ForEach(exerciseNames, id: \.self) { name in
                ExerciseSection(
                    exerciseName: name,
                    sets: session.sets.filter { $0.exerciseName == name },
                    onAdd: { weight, reps in
                        let set = ExerciseSet(exerciseName: name, weight: weight, reps: reps)
                        set.session = session
                        modelContext.insert(set)
                        session.sets.append(set)
                    },
                    onDelete: { set in
                        session.sets.removeAll { $0.id == set.id }
                        modelContext.delete(set)
                    }
                )
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
                Button("Save") {
                    try? modelContext.save()
                    didSave = true
                    dismiss()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(copiedFeedback ? "Copied!" : "Copy as Text") {
                    UIPasteboard.general.string = SessionTextFormatter.text(for: session)
                    copiedFeedback = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        copiedFeedback = false
                    }
                }
            }
        }
        .onDisappear {
            if !didSave {
                modelContext.rollback()
            }
        }
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
                    guard let weight = Double(weightText), weight > 0,
                          let reps = Int(repsText), reps > 0 else { return }
                    onAdd(weight, reps)
                    weightText = ""
                    repsText = ""
                }
                .disabled(!isValidInput)
            }
        }
    }

    private var isValidInput: Bool {
        guard let weight = Double(weightText), weight > 0,
              let reps = Int(repsText), reps > 0 else { return false }
        return true
    }
}

#Preview {
    let session = WorkoutSession(templateName: "Gym")
    return NavigationStack {
        SessionView(session: session)
    }
    .modelContainer(for: [WorkoutSession.self, ExerciseSet.self], inMemory: true)
}
