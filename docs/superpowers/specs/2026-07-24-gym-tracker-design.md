# TrainLog: Gym Session Tracker — Design

## Purpose

Track gym sessions (sets/reps/weight per exercise, plus cardio) fast, between
sets, on a phone. End result of a session is a formatted text summary you can
copy and paste elsewhere (e.g. into a chat or notes app).

## Scope

- Single fixed template for now: **"Gym"** with exercises Bench DB Press,
  Overhead Press, Lat Pull. Adding more templates/exercises later means
  editing a hardcoded list in code — no in-app template editor.
- iOS app, SwiftUI + SwiftData (already scaffolded in the project).
- No auth, no sync, no network. Local persistence only.

## Data model (SwiftData)

Replaces the placeholder `Item` model.

```swift
@Model
final class WorkoutSession {
    var id: UUID
    var templateName: String   // e.g. "Gym"
    var date: Date
    var cardioType: String     // "" if none
    var cardioDuration: String // "" if none
    var cardioDistance: String // "" if none

    @Relationship(deleteRule: .cascade, inverse: \ExerciseSet.session)
    var sets: [ExerciseSet]
}

@Model
final class ExerciseSet {
    var id: UUID
    var exerciseName: String
    var weight: Double  // kg
    var reps: Int
    var session: WorkoutSession?
}
```

`WorkoutTemplate` is **not** a SwiftData model — it's a plain hardcoded Swift
value (struct + static array) defining a name and an ordered list of exercise
names. It exists only to drive the home list and the exercise sections in a
session.

## Screens

### Home (replaces `ContentView`)

- Top: list of workout templates (just "Gym" for now). Tapping one creates a
  new `WorkoutSession` (date = now, templateName = template name), inserts it
  into the model context, and pushes into the Session screen. Multiple
  sessions per day are allowed — every tap starts a fresh session.
- Below: history list of past sessions (`@Query`, sorted by date descending),
  each row showing template name + date. Tap reopens that session in the
  Session screen (view/edit/re-copy). Swipe to delete.

### Session screen

- One section per exercise name in the session's template (looked up from
  the hardcoded template by `templateName`):
  - List of that exercise's logged sets (weight × reps), newest last, swipe
    to delete.
  - "+ Add Set" row opens an inline form (two numeric fields: weight, reps)
    and appends a new `ExerciseSet` on submit.
- Cardio section: three text fields — Type, Duration, Distance. Empty by
  default.
- Toolbar action "Copy as Text": builds the summary via the formatter
  (below) and writes it to `UIPasteboard.general.string`. Shows a brief
  inline confirmation (e.g. a transient "Copied!" label) — no alert dialog.

## Copy-as-text format

Pure function, e.g. `SessionTextFormatter.text(for: WorkoutSession) -> String`.

```
🏋️ {templateName} – {date formatted "MMM d"}

Highest Weight: {max weight across all sets in session} kg

Exercises:
- {exerciseName} — {grouped sets}
...

Cardio:
- {cardio summary}
```

Rules:
- **Highest Weight**: max `weight` across every `ExerciseSet` in the session.
  If the session has zero sets, this line is skipped (no exercises logged
  yet — nothing to report).
- **Exercise line**: sets for that exercise are grouped by identical
  (weight, reps) pairs, in the order first performed. Each group renders as
  `{weight}kg x{reps}`, or `{weight}kg x{reps} (x{count} sets)` when the
  group has more than one set. Groups are joined with `, `. An exercise with
  no logged sets is omitted from the list entirely.
- **Cardio summary**: `{type} - {duration} - {distance}` using only the
  fields that are non-empty, joined with ` - `. If all three are empty,
  render `No`.
- Weight formatting: trim trailing `.0` (e.g. `20kg` not `20.0kg`), otherwise
  show as typed (e.g. `17.5kg`).

## Error handling / validation

- "Add Set" is disabled until both weight and reps have a valid positive
  numeric value entered (numeric keyboard on the fields).
- No other validation needed — this is a local single-user tool, not a
  trust boundary.

## Self-check

`SessionTextFormatter` is pure (no SwiftData/UIKit dependency beyond
`Date` formatting), so its grouping logic is the one part worth a runnable
check. Since the project has no XCTest target and adding one requires
hand-editing the `.xcodeproj` (risky), the check is a `#if DEBUG`
`assert`-based self-test function in the same file, invoked once from
`TrainLogApp.init()` in debug builds. It covers: grouping identical
sets, singleton groups (no count suffix), empty session (no Highest
Weight line), and cardio "No" fallback.

## Explicitly out of scope (skipped for now)

- In-app template/exercise editor — add if the hardcoded "Gym" list stops
  being enough.
- Multiple weight units (lbs) — add if needed.
- Editing an existing set's weight/reps in place — for now, delete + re-add.
- Any kind of sharing beyond clipboard copy (e.g. direct share sheet) — copy
  covers the stated use case (paste elsewhere).
