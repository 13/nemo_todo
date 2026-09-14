# Achievements and celebrations

## Goal

Ticking a task off should feel good. A small, quick reward on every tick,
a bigger one when the day is cleared or a milestone is reached, and a
page of achievements that shows how far you have come. People who want a
quiet, professional tool can switch every part of it off in Settings.

## Decisions

| Topic | Decision |
|---|---|
| Intensity | Tiered: a small tick on every completion, confetti and a cheer only for a cleared Today or an unlocked achievement |
| Sound | A short generated chime, behind its own switch, off by default |
| Where achievements come from | Derived from synced task rows (`done`, `doneAt`, `dueAt`, subtasks); no new table, no server change |
| What is stored | Only a local set of achievement ids already celebrated, in the `kv` table |
| What celebrates | Only a completion made on this device; completions arriving through sync unlock silently |
| Settings | Three per-device switches: Celebrations (on), Sound (off), Achievements (on) |
| Reduced motion | OS "remove animations" skips confetti and the bounce; banners and haptics stay |
| New dependencies | `confetti` and `audioplayers`, both supporting Android and the web |

## Why this shape

Tasks already sync to every device, so anything computed from them agrees
everywhere without touching `nemo_core`, the server or the migration
chain. A synced achievement table would buy nothing a query cannot answer.

Celebrating belongs to the UI layer. `TasksRepository.setDone` is also
reached by the sync engine's writes and by repeat spawning; putting
confetti there would fire on pulls and make data code depend on audio
and animation. The widgets that call `setDone` on a user's tap are the
only place that knows a person just did something.

Confetti on every tick wears off within a day and gets in the way of
ticking off ten tasks in a row. Keeping the big moment rare keeps it
meaningful.

## Achievements

### Completion stats

`features/achievements/domain/completion_stats.dart` holds a pure
function from task and subtask rows to `CompletionStats`:

- `totalDone`: tasks with `done` and not deleted.
- `onTimeDone`: done tasks with a `dueAt` whose `doneAt <= dueAt`. For
  a due date without a time, the end of that local day counts as on time.
- `currentStreak` and `bestStreak`: runs of consecutive local calendar
  days with at least one `doneAt`. Days are computed in the device's
  local time zone from calendar dates, not 24-hour spans, so DST changes
  do not break a streak. The current streak still counts if today has
  no completion yet but yesterday had one.
- `clearedDays`: number of distinct local days on which a completion
  left Today (the same set `TasksRepository` uses: due today or overdue
  and open) empty. Tracked as it happens, see below, because it cannot
  be rebuilt from rows afterwards.
- `maxSubtasksOnDoneTask`: the largest number of non-deleted subtasks on
  a done task.

Deleted tasks and subtasks never count. Tasks in every list the user can
see count, shared lists included; tasks do not record who completed them.

`clearedDays` is the one stat that is not derived: the celebration
controller increments a local `kv` counter when it detects a cleared
Today. It is per device, which is acceptable for a single achievement.

### Catalog

`features/achievements/domain/achievement.dart` defines a fixed,
ordered catalog. Each entry has a stable string id, an icon, l10n keys
for title and description, a target, and a function reading its current
value from `CompletionStats`. Unlocked means value >= target; progress
is `min(value, target) / target`.

| Id | Title (en) | Condition |
|---|---|---|
| `first_done` | First step | 1 task done |
| `done_10` | Getting going | 10 tasks done |
| `done_100` | Centurion | 100 tasks done |
| `done_500` | Unstoppable | 500 tasks done |
| `streak_3` | On a roll | 3-day streak |
| `streak_7` | Week warrior | 7-day streak |
| `streak_30` | Habit formed | 30-day streak |
| `cleared_today` | Clean slate | Today cleared once |
| `on_time_25` | Punctual | 25 tasks done on time |
| `checklist_5` | Checklist master | A task with 5 or more subtasks done |

Ids never change once shipped; they are the keys of the celebrated set.
Streak achievements use `bestStreak`, so once reached they stay unlocked.

### Data and screen

- `data/achievements_repository.dart` watches the rows it needs through
  drift and maps them through `CompletionStats`, exposing
  `Stream<List<AchievementProgress>>`.
- `ui/achievements_providers.dart` wraps it for Riverpod.
- `ui/achievements_screen.dart` shows a responsive grid inside `MaxWidth`:
  unlocked achievements in full colour with their title, locked ones in
  `onSurfaceVariant` with a progress bar and "7 / 10". A header shows
  "4 of 10 unlocked" and the current streak.
- Route `/settings/achievements` in `router.dart`, reached from a tile in the new
  Settings section. The tile is hidden when Achievements is switched off.

## Celebrations

### Controller

`features/celebrations/ui/celebration_controller.dart` holds a
`CelebrationController` in a long-lived `Provider`. The task tile's
`DoneCheck`, the task detail screen and swipe-to-complete call a shared
helper, `completeTask(ref, task, done:)`, which awaits `setDone` and,
when `done` is true, calls `CelebrationController.onCompleted(task)`.

`onCompleted` does, in order:

1. Bookkeeping always runs, whatever the switches say, so turning a
   switch back on never replays old progress; only the event emitted in
   step 4 depends on them.
2. Query whether Today is now empty. If it is, and this day is not
   already recorded, increment the cleared-days counter and remember
   the day.
3. Read current achievement progress; any unlocked id not in the
   celebrated set is newly unlocked. Add those ids to the set.
4. Emit one `CelebrationEvent`, highest tier wins:
   - `achievementUnlocked(list)` if step 3 found any and Achievements is on;
   - `dayCleared` if step 2 found an empty Today;
   - `tick` otherwise.
   When Celebrations is off, only `achievementUnlocked` is emitted, and
   it shows as a banner without confetti or sound.

Unticking does nothing: no event, and the celebrated set is never
shrunk, so re-ticking a task never celebrates the same achievement twice.

### Backfill

On every start, every achievement already unlocked by the
existing history is written to the celebrated set without any event.
The same happens after sign-in or a sync pull: sync writes never call
`onCompleted`, so achievements they unlock are only added to the set,
silently, the next time `onCompleted` or the backfill runs. The
controller also re-runs the silent backfill after each finished sync so a
later local tick is not credited with another device's unlock.

### Presentation

- `DoneCheck` gains a short scale bounce (about 250 ms) and a ring burst
  when it turns done and Celebrations is on; otherwise it keeps today's
  plain `AnimatedContainer`.
- `HapticFeedback.lightImpact()` on `tick`, `mediumImpact()` on the
  bigger tiers, when Celebrations is on. It does nothing on the web.
- `ui/celebration_overlay.dart` is inserted through `MaterialApp.builder`
  above the router. It listens to the controller and:
  - on `dayCleared` or `achievementUnlocked`, plays a short confetti burst
    (0.6 s emission) from the top centre, using colours from the theme's
    colour scheme;
  - on `achievementUnlocked`, shows a dismissible banner with the icon and
    title, tappable to open `/settings/achievements`; several unlocks at once show
    one banner, "3 achievements unlocked";
  - wraps the banner in `Semantics(liveRegion: true)` so screen readers
    announce it.
- The overlay keeps the router as a direct child and gives the confetti
  and banner their own `Overlay` layer, because it sits outside the
  navigator's own overlay and the banner's close button shows a tooltip.
- When `MediaQuery.disableAnimationsOf(context)` is true, no confetti and
  no bounce are shown; the banner still appears.
- Confetti ignores pointer events so it never blocks the next tap.
- The confetti is stopped after its own burst duration by a timer, so its
  state is deterministic under test clocks.
- The confetti keeps emitting when frames are slower than 60 fps
  (`pauseEmissionOnLowFrameRate: false`); the package's default drops
  every particle of a short burst on slow or throttled frames.

### Sound

`features/celebrations/data/celebration_sound.dart` defines
`CelebrationSound` with `Future<void> play()`. The real implementation
uses audioplayers with one bundled asset,
`app/assets/sounds/celebrate.mp3`: a 1.3 s four-note chime generated with
ffmpeg and dedicated to the public domain (CC0), recorded in
`app/assets/sounds/LICENSE.txt`. MP3 plays on Android and in every
supported browser, so no second format ships. It plays at a moderate
volume and respects the device's media volume. It takes transient,
ducking audio focus, so other audio dips under the chime and resumes
after it instead of being stopped. Failures are logged and
swallowed: a missing codec never breaks ticking a task. Tests use a fake.

Sound plays only on `dayCleared` and `achievementUnlocked`, and only
when both Celebrations and Sound are on. On the web a tick is a user
gesture, so autoplay rules allow it.

## Settings

A new section with a `SectionHeader` "Celebrations & achievements", placed after
Appearance in `settings_screen.dart`, as its own widget
`features/celebrations/ui/celebration_settings_section.dart`:

- **Celebrations** (`SwitchListTile`, default on): "Confetti, animations
  and haptics when you complete tasks".
- **Sound** (default off, disabled while Celebrations is off): "Play a
  cheer for big moments".
- **Achievements** (default on): "Show achievements and unlock banners".
  When on, a tile "View achievements" with "4 of 10" opens the screen.

Keys added to `KvKeys`: `celebrations`, `celebrationSound`,
`achievements`, `achievementsSeen` (JSON list of ids),
`clearedDays` (integer) and `lastClearedDay` (ISO date). The three
switches are loaded in the bootstrap step next to `themeMode`, so the
first frame already knows them, and are exposed through notifiers in
`settings_controller.dart` next to `ThemeModeController`. They are
per-device preferences and do not sync. Data export does not include
them, matching the theme mode.

## Localization

All new strings go into `app_en.arb`, `app_de.arb` and `app_it.arb`:
section and switch labels, screen title and header, banner text with
plural forms, and the ten achievement titles and descriptions.

## Error handling

- Any exception in `onCompleted` after `setDone` has succeeded is caught
  and logged; the completion itself is never rolled back or surfaced as
  an error.
- A corrupt `achievementsSeen` value is treated as absent and triggers
  the silent backfill, so a bad value can never cause a flood of
  celebrations.
- Sound and haptics failures are swallowed.

## Testing

- `test/features/achievements/completion_stats_test.dart`: totals ignore
  deleted rows; on-time with and without a due time; streaks across
  midnight, across a DST change, with a gap, and "today not yet done".
- `test/features/achievements/achievement_catalog_test.dart`: ids are
  unique, every entry has l10n keys, unlock and progress at the target
  boundary.
- `test/features/celebrations/celebration_controller_test.dart` with an
  in-memory database and fakes: tick vs dayCleared vs unlock tiers;
  highest tier wins; Celebrations off emits only unlock banners; all off
  emits nothing; unticking emits nothing; an unlock is celebrated once;
  backfill is silent; an unlock that arrived through sync is not
  celebrated by a later local tick.
- `test/features/celebrations/celebration_overlay_test.dart`: confetti
  shows for big tiers, is absent under `disableAnimations`, the banner
  still appears and opens `/settings/achievements`; sound fake called only when
  enabled.
- `test/features/settings/settings_screen_test.dart`: the three switches
  persist to `kv`, Sound is disabled while Celebrations is off, the
  achievements tile hides when Achievements is off.
- `test/features/achievements/achievements_screen_test.dart`: locked and
  unlocked rendering, progress text.
- `test/design/screens_test.dart`: add the achievements screen.

## Docs

README gains a short "Celebrations and achievements" paragraph including
how to turn them off; CHANGELOG gets an entry under the next version.

## Out of scope

Leaderboards or sharing achievements, per-list or per-member
achievements, syncing the celebrated set or the switches, push
notifications for unlocks, user-defined achievements, and custom sounds.
