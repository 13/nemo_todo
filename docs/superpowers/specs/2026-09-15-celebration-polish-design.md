# Celebration polish

## Goal

Close three findings the achievements review left as follow-ups:

- A screen-reader user cannot reach the unlock banner before it hides (M6).
- A sync finishing at the wrong moment can swallow a tap's unlock (M5).
- The chime may stay silent in Safari, and nothing says so (M7).

## Decisions

| Topic | Decision |
|---|---|
| Banner under accessible navigation | No auto-hide while `MediaQuery.accessibleNavigationOf` is true; the banner stays until closed or tapped |
| Banner otherwise | Unchanged: hides after 4 s |
| Tap vs backfill | The controller runs work one step at a time; a tap's write and its celebration check are one step, and a backfill waits its turn |
| Safari | Documented as a known limit (README and spec), no code change |

## Why this shape

**M6.** The banner is a live region, so a screen reader announces it. With
TalkBack or switch access, though, moving focus to its "open" or "close"
action takes longer than 4 s. Flutter reports that navigation mode as
`MediaQuery.accessibleNavigationOf`. Waiting for a deliberate close there,
and only there, keeps the banner short for everyone else.

**M5.** `completeTask` writes the task done, then asks the controller what the
completion earned. The controller reads the celebrated set, compares it with
what is reached now, and records the difference. A backfill (run when a sync
finishes) records everything reached as celebrated. If one lands between the
tap's write and the controller's read, it records the tap's own unlock first,
and the tap finds nothing new: no banner.

Queueing calls alone would not fix it, because the backfill is requested
between the write and the check. So the write moves into the queued step:
`onCompleted(task, write:)` performs `write` and then the check as one turn.
A backfill asked for meanwhile runs after it. Nothing else changes: unticking
still writes directly, and a backfill still records silently.

**M7.** Safari lets a page start sound only in direct response to a tap. The
chime starts after the controller's database queries, so Safari may refuse it;
the refusal is caught and logged, so the result is silence. Unlocking the
audio element on the first tap might work but cannot be verified here (no
Safari on Linux). A clear note costs nothing and is true.

## Changes

- `app/lib/features/celebrations/ui/celebration_overlay.dart`, `_show`: start
  the 4 s hide timer only when `!MediaQuery.accessibleNavigationOf(context)`.
- `app/lib/features/celebrations/ui/celebration_controller.dart`:
  - A private `_inTurn(step)` chains each step after the previous one, and
    keeps the chain alive if a step throws.
  - `onCompleted(Task task, {Future<void> Function()? write})` runs `write`
    (when given) and then the existing check, in one turn. A failing `write`
    still throws to the caller, as a failed `setDone` does today, without
    breaking the chain.
  - `backfill()` runs in a turn.
- `app/lib/features/celebrations/ui/complete_task.dart`: when `done` is true,
  call `celebrations.onCompleted(task, write: () => tasks.setDone(task.id,
  done: true))`; unticking stays a direct `setDone(done: false)`. Both
  providers are still read before any await.
- `README.md`, celebrations bullet: add that in Safari the sound may stay
  silent, because Safari plays sound only right after a tap.
- `docs/superpowers/specs/2026-09-14-achievements-celebrations-design.md`,
  Sound section: the same known limit, one sentence.

## Testing

- **Overlay:** with `FakeAccessibilityFeatures(accessibleNavigation: true)`,
  the banner is still shown 6 s after an unlock, and the close button removes
  it. Without it, the banner is gone after 4 s.
- **Controller:** a backfill requested inside a tap's `write` (as a sync
  finishing then would) no longer swallows the unlock. The tap emits
  `AchievementsUnlocked(['first_done'])`, and the backfill completes
  afterwards.
- **Regression:** existing controller, overlay and swipe tests pass
  unchanged; `completeTask` keeps celebrating swipes and taps.
