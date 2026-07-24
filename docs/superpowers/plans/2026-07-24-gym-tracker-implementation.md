# Gym Session Tracker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the TrainLog iOS app per `docs/superpowers/specs/2026-07-24-gym-tracker-design.md` — a home list of workout templates, a session screen for logging sets/reps/cardio between sets, and a "Copy as Text" summary.

**Architecture:** SwiftUI + SwiftData, replacing the placeholder `Item` model with `WorkoutSession`/`ExerciseSet`. `WorkoutTemplate` is a plain hardcoded value type (not persisted). A pure `SessionTextFormatter` enum builds the clipboard text and carries its own `#if DEBUG` self-test since the project has no XCTest target.

**Tech Stack:** Swift 5, SwiftUI, SwiftData, iOS 26.2 deployment target, Xcode project with file-system-synchronized groups (Xcode 16+ format).

## Global Constraints

- Bundle identifier: `com.uwaisalqadri.TrainLog`. Scheme: `TrainLog`. Project file: `TrainLog.xcodeproj`.
- Deployment target: iOS 26.2. Swift version: 5.0.
- This project uses `PBXFileSystemSynchronizedRootGroup` — any `.swift` file placed under `TrainLog/` is automatically part of the build target. **Do not hand-edit `project.pbxproj`** to add/remove file references; just create/delete files in `TrainLog/` with the filesystem.
- Only one workout template exists for now: `"Gym"` with exercises `["Bench DB Press", "Overhead Press", "Lat Pull"]`. Do not build a template editor.
- Weight unit is always kg; no unit conversion.
- No XCTest target exists. Per the spec's "Self-check" section, the one runnable check for the formatter's grouping logic is a `#if DEBUG` `assert`-based `runSelfTest()` function, invoked once from `TrainLogApp.init()`.
- Verification commands assume the "iPhone 17 Pro" simulator (iOS 26.2 runtime) is available. If it isn't, substitute any booted simulator running iOS 26.2+ with `xcrun simctl list devices available`.

---

### Task 1: Data models

**Files:**
- Create: `TrainLog/WorkoutTemplate.swift`
- Create: `TrainLog/WorkoutSession.swift`

**Interfaces:**
- Produces: `struct WorkoutTemplate: Identifiable { let id: UUID; let name: String; let exerciseNames: [String]; static let all: [WorkoutTemplate]; static func template(named: String) -> WorkoutTemplate? }`
- Produces: `@Model final class WorkoutSession { var id: UUID; var templateName: String; var date: Date; var cardioType: String; var cardioDuration: String; var cardioDistance: String; var sets: [ExerciseSet]; init(templateName: String, date: Date = Date()) }`
- Produces: `@Model final class ExerciseSet { var id: UUID; var exerciseName: String; var weight: Double; var reps: Int; var session: WorkoutSession?; init(exerciseName: String, weight: Double, reps: Int) }`

- [ ] **Step 1: Create `TrainLog/WorkoutTemplate.swift`**

```swift
import Foundation

struct WorkoutTemplate: Identifiable {
    let id = UUID()
    let name: String
    let exerciseNames: [String]

    static let all: [WorkoutTemplate] = [
        WorkoutTemplate(name: "Gym", exerciseNames: ["Bench DB Press", "Overhead Press", "Lat Pull"])
    ]

    static func template(named name: String) -> WorkoutTemplate? {
        all.first { $0.name == name }
    }
}
```

- [ ] **Step 2: Create `TrainLog/WorkoutSession.swift`**

```swift
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
```

- [ ] **Step 3: Build to verify the new files compile**

Run: `xcodebuild -project TrainLog.xcodeproj -scheme TrainLog -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **` (these files aren't used anywhere yet, but must compile standalone).

- [ ] **Step 4: Commit**

```bash
git add TrainLog/WorkoutTemplate.swift TrainLog/WorkoutSession.swift
git commit -m "Add WorkoutTemplate, WorkoutSession, and ExerciseSet models"
```

---

### Task 2: Copy-as-text formatter

**Files:**
- Create: `TrainLog/SessionTextFormatter.swift`

**Interfaces:**
- Consumes: `WorkoutSession`, `ExerciseSet`, `WorkoutTemplate.template(named:)` from Task 1.
- Produces: `enum SessionTextFormatter { static func text(for: WorkoutSession) -> String; static func formatWeight(_ weight: Double) -> String; #if DEBUG static func runSelfTest() }`. `formatWeight` and `text(for:)` are used by `SessionView` in Task 3. `runSelfTest()` is called by `TrainLogApp.init()` in Task 4.

- [ ] **Step 1: Create `TrainLog/SessionTextFormatter.swift`**

```swift
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

        print("SessionTextFormatter self-test passed")
    }
    #endif
}
```

- [ ] **Step 2: Run the self-test standalone (fast feedback, no simulator needed)**

```bash
cat TrainLog/WorkoutTemplate.swift TrainLog/WorkoutSession.swift TrainLog/SessionTextFormatter.swift > /tmp/formatter_check.swift
echo 'SessionTextFormatter.runSelfTest()' >> /tmp/formatter_check.swift
swift -D DEBUG /tmp/formatter_check.swift
```

`-D DEBUG` is required — `runSelfTest()` is wrapped in `#if DEBUG`, which the `swift` command-line tool does not define by default (unlike an Xcode Debug build, which sets it via `SWIFT_ACTIVE_COMPILATION_CONDITIONS`).

Expected: prints `SessionTextFormatter self-test passed`, exits with code 0 (no assertion crash / stack trace).

- [ ] **Step 3: Build the full project to verify it still compiles**

Run: `xcodebuild -project TrainLog.xcodeproj -scheme TrainLog -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add TrainLog/SessionTextFormatter.swift
git commit -m "Add SessionTextFormatter with debug self-test"
```

---

### Task 3: Session tracking screen

**Files:**
- Create: `TrainLog/SessionView.swift`

**Interfaces:**
- Consumes: `WorkoutSession`, `ExerciseSet`, `WorkoutTemplate.template(named:)` (Task 1), `SessionTextFormatter.text(for:)` / `.formatWeight(_:)` (Task 2).
- Produces: `struct SessionView: View { init(session: WorkoutSession) }` — used by `ContentView` in Task 4 as a `navigationDestination`.

- [ ] **Step 1: Create `TrainLog/SessionView.swift`**

```swift
import SwiftUI
import SwiftData

struct SessionView: View {
    @Bindable var session: WorkoutSession
    @Environment(\.modelContext) private var modelContext
    @State private var copiedFeedback = false

    private var exerciseNames: [String] {
        WorkoutTemplate.template(named: session.templateName)?.exerciseNames ?? []
    }

    var body: some View {
        Form {
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
                Button(copiedFeedback ? "Copied!" : "Copy as Text") {
                    UIPasteboard.general.string = SessionTextFormatter.text(for: session)
                    copiedFeedback = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        copiedFeedback = false
                    }
                }
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
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild -project TrainLog.xcodeproj -scheme TrainLog -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add TrainLog/SessionView.swift
git commit -m "Add SessionView for logging sets, reps, and cardio"
```

---

### Task 4: Home screen and app wiring

**Files:**
- Modify: `TrainLog/ContentView.swift` (full replace)
- Modify: `TrainLog/TrainLogApp.swift` (full replace)
- Delete: `TrainLog/Item.swift`

**Interfaces:**
- Consumes: `WorkoutTemplate.all` (Task 1), `WorkoutSession`/`ExerciseSet` (Task 1), `SessionView(session:)` (Task 3), `SessionTextFormatter.runSelfTest()` (Task 2).

- [ ] **Step 1: Replace `TrainLog/ContentView.swift`**

```swift
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
```

- [ ] **Step 2: Replace `TrainLog/TrainLogApp.swift`**

```swift
import SwiftUI
import SwiftData

@main
struct TrainLogApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            WorkoutSession.self,
            ExerciseSet.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        #if DEBUG
        SessionTextFormatter.runSelfTest()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
```

- [ ] **Step 3: Delete `TrainLog/Item.swift`**

```bash
rm TrainLog/Item.swift
```

- [ ] **Step 4: Build to verify the whole app compiles**

Run: `xcodebuild -project TrainLog.xcodeproj -scheme TrainLog -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 5: Commit**

```bash
git add -A TrainLog/ContentView.swift TrainLog/TrainLogApp.swift TrainLog/Item.swift
git commit -m "Wire home screen, session navigation, and SwiftData schema"
```

---

### Task 5: End-to-end simulator verification

**Files:** none (verification only)

**Interfaces:** none — this task exercises the full app built in Tasks 1–4.

- [ ] **Step 1: Build for the simulator with a known output path**

```bash
xcodebuild -project TrainLog.xcodeproj -scheme TrainLog -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath /tmp/trainlog-build build
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 2: Boot the simulator and install the app**

```bash
xcrun simctl bootstatus "iPhone 17 Pro" -b
xcrun simctl install "iPhone 17 Pro" /tmp/trainlog-build/Build/Products/Debug-iphonesimulator/TrainLog.app
```

Expected: both commands exit 0 with no error output.

- [ ] **Step 3: Launch and capture the debug self-test output**

```bash
timeout 5 xcrun simctl launch --console-pty "iPhone 17 Pro" com.uwaisalqadri.TrainLog || true
```

Expected: output includes `SessionTextFormatter self-test passed` and does NOT include `Fatal error` or `Assertion failed` (an `assert()` failure in `runSelfTest()` would crash the launch instead of printing the pass line).

- [ ] **Step 4: Manual smoke test in Simulator.app**

Open Simulator.app (already booted from Step 2), tap "Gym" on the home list, add a set to each exercise (e.g. 17.5kg × 10, 20kg × 8), fill in a cardio field, tap "Copy as Text", and paste into Notes to confirm the format matches the spec example:

```
🏋️ Gym – Jul 24

Highest Weight: 20 kg

Exercises:
- Bench DB Press — 17.5kg x10
- Overhead Press — 20kg x8

Cardio:
- Running - 30 min
```

Confirm: the home screen's History section now shows the new "Gym" session after navigating back.

- [ ] **Step 5: Commit any fixes found during manual testing, or confirm no changes needed**

If Step 3 or Step 4 surfaced a bug, fix it in the relevant file from Tasks 1–4, re-run the affected verification step, then commit with a message describing the fix. If everything passed as-is, no commit is needed for this task.
