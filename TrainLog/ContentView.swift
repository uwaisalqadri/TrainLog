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

                if sessions.isEmpty {
                    Section("History") {
                        Text("No sessions yet")
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach(weekGroups, id: \.weekStart) { group in
                    Section(weekLabel(for: group.weekStart)) {
                        ForEach(group.sessions) { session in
                            NavigationLink(value: session) {
                                VStack(alignment: .leading) {
                                    Text(session.templateName)
                                    Text(session.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete { offsets in
                            deleteSessions(group.sessions, at: offsets)
                        }
                    }
                }
            }
            .navigationTitle("TrainLog")
            .navigationDestination(for: WorkoutSession.self) { session in
                SessionView(session: session)
            }
        }
    }

    private var weekGroups: [(weekStart: Date, sessions: [WorkoutSession])] {
        let calendar = Calendar.current
        var groups: [(weekStart: Date, sessions: [WorkoutSession])] = []
        for session in sessions {
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: session.date)?.start ?? session.date
            if let lastIndex = groups.indices.last, groups[lastIndex].weekStart == weekStart {
                groups[lastIndex].sessions.append(session)
            } else {
                groups.append((weekStart: weekStart, sessions: [session]))
            }
        }
        return groups
    }

    private func weekLabel(for weekStart: Date) -> String {
        let calendar = Calendar.current
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        return "\(weekStart.formatted(.dateTime.month(.abbreviated).day())) – \(weekEnd.formatted(.dateTime.month(.abbreviated).day()))"
    }

    private func startSession(for template: WorkoutTemplate) {
        let session = WorkoutSession(templateName: template.name)
        path.append(session)
    }

    private func deleteSessions(_ groupSessions: [WorkoutSession], at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(groupSessions[index])
        }
        try? modelContext.save()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [WorkoutSession.self, ExerciseSet.self], inMemory: true)
}
