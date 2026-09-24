# Motivation messages and Today progress

## Goal

Ticking a task off should feel good in words as well as motion. Every
completion made on this device gets a short, varied, sincere message; the
Today screen shows how far the day has come; and someone coming back after
a break is welcomed, never scolded. It builds on the achievements and
celebrations feature (`2026-09-14-achievements-celebrations-design.md`)
and stays under its Celebrations switch.

## Decisions

| Topic | Decision |
|---|---|
| Where | A message after each tick; a progress bar and line in the Today header; a welcome-back line after a break |
| Frequency | Every completion made by a tap on this device. Never on untick, never for rows arriving through sync |
| Look | A small floating pill near the bottom, above the navigation bar, about 2.5 s, fade in/out; ignores pointer events; a newer message replaces it at once |
| Tone | Warm and calm: short, sincere, grown-up. No emoji, at most rare exclamation marks, never guilt ("you missed", overdue counts) |
| Variety | Each situation has several variants; a message shown among the last five is not picked again when another is available |
| Achievements | An unlock keeps its existing banner and shows no pill |
| Swipe to complete | Its Undo snackbar shows the message instead of "Task completed"; no pill |
| Switch | Messages, the pill and the header's line follow Celebrations. Off: no pill, snackbar says "Task completed", header shows only the bar |
| Progress bar | Always shown when Today has tasks, regardless of the switch: it is information, not celebration |
| Languages | en, de, it (de/it drafted by us; to be checked by a native speaker) |

## Why this shape

The celebration controller already runs once per tap-completion, in turn
with its own write, already knows whether Today was cleared, and already
emits one event that the overlay presents. Choosing the message there
keeps one place deciding what a tick earns, and inherits its rules: only
taps celebrate, sync never does, the switch is read at event time.

The choice itself is a pure function from a small context to a message id,
so every rule is a unit test and the controller only gathers the context.

Showing a message on every tick risks becoming noise. The mitigations are
variety (several variants per situation, no repeats among the last five),
situational messages that carry information ("One to go", "3 of 5 done
today"), and a presentation that never blocks: the pill ignores taps and
is replaced, not queued.

## Components

### `features/celebrations/domain/motivation.dart` (pure Dart)

```dart
enum MotivationKind {
  dayCleared,   // Today just became empty
  lastOne,      // exactly one Today task left open
  halfway,      // this tick crossed half of Today
  streakDay,    // first completion today and the streak is >= 2 days
  firstOfDay,   // first completion today, no streak
  overdue,      // the task was due before today
  progress,     // "{done} of {total} done today"
  generic,      // anything else
}

class MotivationContext {
  const MotivationContext({
    required this.todayDone,     // Today tasks done today, including this one
    required this.todayTotal,    // todayDone + Today tasks still open
    required this.wasInToday,    // the ticked task counted in Today
    required this.firstToday,    // no other completion today before this one
    required this.streak,        // current streak in days, including today
    required this.wasOverdue,    // dueAt before the start of today
    required this.cleared,       // Today is empty now
  });
  ...
}

class Motivation {
  const Motivation(this.kind, this.variant);
  final MotivationKind kind;
  final int variant; // index into that kind's variants
}

/// Picks the message for a completion. Highest priority wins:
/// dayCleared > lastOne > halfway > streakDay > firstOfDay > overdue >
/// (progress or generic). [recent] holds the last messages shown, newest
/// last; a variant among them is skipped while another is left. [random]
/// is injected so tests are deterministic.
Motivation pickMotivation(
  MotivationContext c, {
  required List<Motivation> recent,
  required Random random,
});

/// How many variants each kind has; the l10n layer must provide exactly
/// these.
const Map<MotivationKind, int> motivationVariants = { ... };
```

Rules:

- `halfway`: `wasInToday && todayTotal >= 4 && todayDone * 2 >= todayTotal
  && (todayDone - 1) * 2 < todayTotal` (crossed by this tick; small days
  skip it, "One to go" covers them).
- `lastOne`: `wasInToday && todayTotal - todayDone == 1`.
- `streakDay`/`firstOfDay`: `firstToday`; `streakDay` when `streak >= 2`.
- `progress` vs `generic`: when `wasInToday && todayTotal >= 2`, choose
  `progress` about one time in three, else `generic`, so the count shows
  up without every line being a count.
- Variant choice: uniform among the kind's variants not in `recent`
  (same kind and index); if all are recent, uniform among all.

### Strings

`features/celebrations/ui/motivation_text.dart`:
`String motivationText(L l, Motivation m, MotivationContext c)` maps to
l10n keys `motivation<Kind><n>` (e.g. `motivationGeneric3`). `progress`
and `streakDay` take placeholders (`{done}`, `{total}`, `{days}`). A test
asserts every kind has exactly `motivationVariants[kind]` keys resolving
in en, de and it.

English drafts (de/it translated with the same tone):

- dayCleared (4): "All clear for today. Enjoy it." / "That's everything
  for today. Well done." / "Today's list is empty. Nice work." / "All
  done. Time for something you enjoy."
- lastOne (3): "One to go." / "Just one left." / "Nearly there. One more."
- halfway (3): "Halfway there." / "Half of today, done." / "Good pace.
  Halfway through."
- streakDay (3): "Day {days} in a row." / "{days} days running. Keep it
  gentle." / "Another day, another step. {days} in a row."
- firstOfDay (4): "Good start." / "First one done. The rest is easier." /
  "And the day is moving." / "Off to a good start."
- overdue (3): "That one's been waiting. Good to have it gone." / "Off
  your mind at last." / "Finally done. That feels better."
- progress (2): "{done} of {total} done today." / "{done} down, {left} to
  go." (`{left}` = total - done)
- generic (12): "Nice, one less thing." / "Done and dusted." / "Progress
  feels good." / "Another one done." / "Ticked off." / "That's handled." /
  "Good work." / "One step further." / "Nicely done." / "Crossed off." /
  "Keep going, gently." / "Small steps count."

### Controller

`CelebrationController`:

- Gains `final _recent = <Motivation>[]` (in memory, last five) and an
  injected `Random`.
- `_celebrate` gathers the context from `AchievementsRepository` (new
  query `todayCounts()` -> `(done, open)` for Today as `TasksRepository`
  defines it, done meaning `doneAt` today; `firstCompletionToday` is
  `done == 1` among all tasks completed today -- a new `doneTodayCount()`;
  `streak` from `stats().currentStreak`; `wasOverdue` from the task's
  `dueAt` against the start of today), picks a motivation, records it in
  `_recent`, and attaches it to the event it already emits:
  `TickCelebration(motivation, context)` and
  `DayClearedCelebration(motivation, context)`.
  `AchievementsUnlocked` carries none.
- When Celebrations is off, no motivation is picked (it emits nothing, as
  today, unless an achievement unlocked).
- The queries run in the controller's existing turn, after the write, so
  counts include this completion.

### Presentation

- `CelebrationOverlay._show`: for `TickCelebration` and
  `DayClearedCelebration` with a motivation, shows `MotivationPill` in its
  existing overlay layer: bottom-centred, above the navigation bar
  (`MediaQuery.paddingOf` + the shell's nav height; `kBottomNavigationBarHeight`
  as the fallback), `Material` pill in `inverseSurface` /
  `onInverseSurface`, a check icon and the text, max width 480, one line
  wrapping to two at most. Fades in 150 ms, holds 2.5 s, fades out 200 ms;
  a new message cancels the timer and swaps the text immediately.
  `IgnorePointer` around it. `Semantics(liveRegion: true)`. Reduced
  motion: no fade, same hold. Keyed `motivation-pill`.
- Day cleared: pill plus the existing confetti and sound.
- Swipe to complete (`task_list_view.dart`): `completeTask(ref, task,
  done: true, showPill: false)` passes `showPill` through `onCompleted`
  into the event, and returns the emitted event's `(Motivation,
  MotivationContext)?`. The overlay skips the pill when `showPill` is
  false. The swipe maps the returned value with `motivationText` for its
  snackbar, or uses `tasksCompletedSnack` when it is null (Celebrations
  off, or an achievement unlocked). Tap paths keep the default
  `showPill: true` and ignore the return value.

### Today header

`features/tasks/ui/today_progress.dart`, `TodayProgress` widget, the
first item of `TodayScreen`'s body, below `UpdateBanner` and above the
list, inside the same `MaxWidth` as the list, padded 16 dp horizontally:

- Data: a provider `todayProgressProvider` streaming `(done, total)`
  from the Today task stream the screen already watches (done today +
  open) -- no new query.
- Hidden when `total == 0`.
- `LinearProgressIndicator` (value `done / total`, 4 dp, rounded) and
  "{done} of {total} done".
- A line, only while Celebrations is on:
  - `done == 0` and the last completion anywhere was 3+ days ago (or
    never, with at least one task done ever): welcome back, 2 variants:
    "Welcome back. One small thing is a good start." / "Good to see you.
    Start with something easy."
  - `done == 0` otherwise: 3 variants: "A fresh start." / "Pick one to
    begin." / "One thing at a time."
  - `done == total`: "All clear. Enjoy the rest of your day."
  - otherwise no line.
  Variant chosen by day (`dayOfYear % n`), so it does not flicker on
  rebuild.
- Last completion date: from `AchievementsRepository.stats()` (add
  `lastDoneAt` to `CompletionStats`).

## Error handling

A failing query while gathering the context drops the motivation (event
without text, no pill), logged like other celebration failures; the tick
itself is never affected.

## Testing

- Unit: `pickMotivation` priority order for each kind; halfway crossing
  only once; small days skip halfway; streakDay vs firstOfDay; overdue;
  progress/generic split with a seeded `Random`; no repeat among the last
  five; all-recent fallback. `motivationVariants` matches l10n in en/de/it.
  `CompletionStats.lastDoneAt`. Repository `todayCounts`/`doneTodayCount`.
- Controller: tick emits a motivation with correct context; switch off
  emits none; achievement unlock carries none; untick emits nothing.
- Widget: pill shows the text, replaces on a second tick, hides after the
  hold, ignores taps, is a live region, appears without fade under reduced
  motion; no pill for swipe, whose snackbar carries the message; switch
  off: snackbar says "Task completed". Today header: hidden when empty,
  counts, fresh-start line, all-clear line, welcome-back line, no line
  with Celebrations off.
