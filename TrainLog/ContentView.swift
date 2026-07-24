import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.date, order: .reverse) private var sessions: [WorkoutSession]
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section("Start Workout") {
                    ForEach(WorkoutTemplate.all) { template in
                        Button(template.name) {
                            startSession(for: template)
                        }
                    }
                }

                Section("History") {
                    if sessions.isEmpty {
                        Text("No sessions yet")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(sessions) { session in
                        NavigationLink(value: session) {
                            VStack(alignment: .leading) {
                                Text(session.templateName)
                                Text(session.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: deleteSessions)
                }
            }
            .navigationTitle("TrainLog")
            .navigationDestination(for: WorkoutSession.self) { session in
                SessionView(session: session)
            }
        }
    }

    private func startSession(for template: WorkoutTemplate) {
        let session = WorkoutSession(templateName: template.name)
        modelContext.insert(session)
        path.append(session)
    }

    private func deleteSessions(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(sessions[index])
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [WorkoutSession.self, ExerciseSet.self], inMemory: true)
}
