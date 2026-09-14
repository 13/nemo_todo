# Achievements and Celebrations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reward completing tasks with a tiered celebration (bounce, confetti, sound, banner) and a page of ten achievements, all switchable off in Settings.

**Architecture:** Achievements are computed from the task and subtask rows already on the device (`CompletionStats` → catalog), so nothing new syncs. A `CelebrationController` is told about completions made by a person on this device, does its bookkeeping in the `kv` table, and emits one `CelebrationEvent`; a `CelebrationOverlay` above the router turns that into confetti, haptics, sound and a banner. Three per-device switches live in `kv` and are loaded at bootstrap like the theme.

**Tech Stack:** Flutter 3.47.2 (via fvm), Riverpod 3 with riverpod_generator, drift, gen-l10n (en/de/it), `confetti` 0.8.0, `audioplayers` 6.8.1.

Spec: `docs/superpowers/specs/2026-09-14-achievements-celebrations-design.md`

## Global Constraints

- Flutter is not on PATH. Before any command: `export PATH="$HOME/fvm/versions/3.47.2/bin:$PATH"`. Flutter and dart commands below run from `app/` unless stated; `git` commands run from the repository root.
- After editing any `.arb` file run `flutter gen-l10n`; after adding or changing `@riverpod`/`@Riverpod` code run `dart run build_runner build`. Generated files (`lib/l10n/app_localizations*.dart`, `*.g.dart`) are committed.
- Every new string goes into `app_en.arb`, `app_de.arb` and `app_it.arb`; `test/l10n/translations_test.dart` fails if the key sets differ. `@` metadata goes into `app_en.arb` only.
- Lints are `very_good_analysis`: no positional bool parameters, `unawaited(...)` for fire-and-forget futures, `on Object catch` rather than a bare `catch`.
- Widget tests use `appTest` + `pumpApp` from `test/support/pump_app.dart`; the fixed clock is `testNow = DateTime(2026, 9, 7, 10)`.
- Achievement ids are stored on devices and must never change: `first_done`, `done_10`, `done_100`, `done_500`, `streak_3`, `streak_7`, `streak_30`, `cleared_today`, `on_time_25`, `checklist_5`.
- Defaults: Celebrations on, Sound off, Achievements on. The switches are per device and never sync.
- Only a completion made by a person on this device (a tap on `DoneCheck`) may celebrate. Rows arriving through sync unlock silently.
- Reduced motion (`MediaQuery.disableAnimationsOf`) skips confetti and the bounce; banners and haptics stay.
- Commit messages follow the repo's conventional style (`feat(app): …`, `docs: …`) and end with the attribution lines from the session.

## File Structure

Create:
- `app/lib/features/achievements/domain/completion_stats.dart`: pure stats from rows.
- `app/lib/features/achievements/domain/achievement.dart`: `Achievement`, `AchievementProgress`, `achievementCatalog`, `progressOf`.
- `app/lib/features/achievements/data/achievements_repository.dart`: drift reads, cleared-day counter, celebrated set.
- `app/lib/features/achievements/ui/achievements_providers.dart` (+ `.g.dart`): repository and stats stream providers.
- `app/lib/features/achievements/ui/achievements_screen.dart`: the grid page.
- `app/lib/features/celebrations/data/celebration_sound.dart`: sound interface, asset player, provider.
- `app/lib/features/celebrations/ui/celebration_controller.dart`: events, controller, provider.
- `app/lib/features/celebrations/ui/complete_task.dart`: the one way a tap completes a task.
- `app/lib/features/celebrations/ui/celebration_overlay.dart`: confetti, haptics, sound, banner host.
- `app/lib/features/celebrations/ui/achievement_banner.dart`: the unlock banner.
- `app/lib/features/celebrations/ui/celebration_settings_section.dart`: the Settings section.
- `app/assets/sounds/celebrate.mp3`, `app/assets/sounds/LICENSE.txt`.
- Tests: `app/test/features/achievements/{completion_stats,achievement_catalog,achievements_repository,achievements_screen}_test.dart`, `app/test/features/celebrations/{celebration_controller,celebration_overlay}_test.dart`, `app/test/support/fake_celebrations.dart`.

Modify:
- `app/lib/core/db/kv_store.dart`: new `KvKeys`.
- `app/lib/core/providers.dart`: `AppBootstrap` switch fields.
- `app/lib/features/settings/ui/settings_controller.dart` (+ `.g.dart`): three switch notifiers.
- `app/lib/features/settings/ui/settings_screen.dart`: insert the section.
- `app/lib/router.dart`: `/settings/achievements`.
- `app/lib/core/widgets/task_tile.dart`: `DoneCheck` bounce, tile uses `completeTask`.
- `app/lib/features/tasks/ui/task_detail_screen.dart`: uses `completeTask`.
- `app/lib/app.dart`, `app/test/support/pump_app.dart`: overlay in `builder`, test params.
- `app/pubspec.yaml`, `app/lib/l10n/app_{en,de,it}.arb`.
- `app/test/features/settings/settings_screen_test.dart`, `app/test/design/screens_test.dart`.
- `README.md`, `CHANGELOG.md`, the spec (amendments).

---

### Task 1: Completion stats

**Files:**
- Create: `app/lib/features/achievements/domain/completion_stats.dart`
- Test: `app/test/features/achievements/completion_stats_test.dart`

**Interfaces:**
- Consumes: `Task`, `Subtask` from `package:nemo_core/nemo_core.dart`; `startOfDay`, `dayStartMsFrom` from `package:nemo/utils/dates.dart`.
- Produces: `class CompletionStats { const CompletionStats({int totalDone, int onTimeDone, int currentStreak, int bestStreak, int clearedDays, int maxSubtasksOnDoneTask}); factory CompletionStats.from({required Iterable<Task> tasks, required Iterable<Subtask> subtasks, required DateTime now, int clearedDays = 0}); }` with final `int` fields of the same names.

- [ ] **Step 1: Write the failing test**

`app/test/features/achievements/completion_stats_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/achievements/domain/completion_stats.dart';
import 'package:nemo_core/nemo_core.dart';

final now = DateTime(2026, 9, 7, 10);

Task done(
  String id,
  DateTime at, {
  DateTime? due,
  bool hasTime = false,
  bool deleted = false,
}) => Task(
  id: id,
  listId: 'l',
  title: id,
  sortKey: 'a',
  updatedAt: '0',
  done: true,
  doneAt: at.millisecondsSinceEpoch,
  dueAt: due?.millisecondsSinceEpoch,
  dueHasTime: hasTime,
  deletedAt: deleted ? '1' : null,
);

Task open(String id) =>
    Task(id: id, listId: 'l', title: id, sortKey: 'a', updatedAt: '0');

Subtask sub(String id, String taskId, {bool deleted = false}) => Subtask(
  id: id,
  taskId: taskId,
  title: id,
  sortKey: 'a',
  updatedAt: '0',
  deletedAt: deleted ? '1' : null,
);

CompletionStats of(
  List<Task> tasks, {
  List<Subtask> subtasks = const [],
  DateTime? at,
  int cleared = 0,
}) => CompletionStats.from(
  tasks: tasks,
  subtasks: subtasks,
  now: at ?? now,
  clearedDays: cleared,
);

void main() {
  test('nothing done is all zeros', () {
    final s = of([open('a')]);
    expect(s.totalDone, 0);
    expect(s.onTimeDone, 0);
    expect(s.currentStreak, 0);
    expect(s.bestStreak, 0);
    expect(s.maxSubtasksOnDoneTask, 0);
  });

  test('counts done tasks and ignores open and deleted ones', () {
    final s = of([done('a', now), done('b', now, deleted: true), open('c')]);
    expect(s.totalDone, 1);
  });

  test('on time is up to the due time, or anywhere in the due day', () {
    final s = of([
      // Due on the 7th without a time, done that morning: on time.
      done('a', DateTime(2026, 9, 7, 10), due: DateTime(2026, 9, 7)),
      // Due on the 7th without a time, done just after midnight: late.
      done('b', DateTime(2026, 9, 8, 0, 30), due: DateTime(2026, 9, 7)),
      // Due at 09:00, done at 10:00: late.
      done('c', now, due: DateTime(2026, 9, 7, 9), hasTime: true),
      // Due at 09:00, done at 08:59: on time.
      done(
        'd',
        DateTime(2026, 9, 7, 8, 59),
        due: DateTime(2026, 9, 7, 9),
        hasTime: true,
      ),
      // No due date never counts as on time.
      done('e', now),
    ]);
    expect(s.onTimeDone, 2);
  });

  test('streak counts consecutive local days ending today', () {
    final s = of([
      done('a', DateTime(2026, 9, 5, 23, 30)),
      done('b', DateTime(2026, 9, 6, 0, 30)),
      done('c', DateTime(2026, 9, 7, 8)),
    ]);
    expect(s.currentStreak, 3);
    expect(s.bestStreak, 3);
  });

  test('a streak survives a day with nothing done yet', () {
    final s = of([
      done('a', DateTime(2026, 9, 5, 12)),
      done('b', DateTime(2026, 9, 6, 12)),
    ]);
    expect(s.currentStreak, 2);
  });

  test('a gap ends the current streak but not the best one', () {
    final s = of([
      for (var d = 1; d <= 4; d++) done('a$d', DateTime(2026, 9, d, 12)),
      done('b', DateTime(2026, 9, 7, 9)),
    ]);
    expect(s.currentStreak, 1);
    expect(s.bestStreak, 4);
  });

  test('a streak crosses a daylight saving change', () {
    // Europe moves its clocks on 29 March 2026. Calendar days, not 24-hour
    // spans, keep this a three-day streak in any time zone; run the file
    // with TZ=Europe/Berlin to exercise the change itself.
    final s = of([
      done('a', DateTime(2026, 3, 28, 23, 30)),
      done('b', DateTime(2026, 3, 29, 23, 30)),
      done('c', DateTime(2026, 3, 30, 0, 30)),
    ], at: DateTime(2026, 3, 30, 12));
    expect(s.currentStreak, 3);
  });

  test('largest checklist counts live subtasks of done tasks only', () {
    final s = of(
      [done('a', now), open('b')],
      subtasks: [
        for (var i = 0; i < 5; i++) sub('a$i', 'a'),
        sub('ax', 'a', deleted: true),
        for (var i = 0; i < 7; i++) sub('b$i', 'b'),
      ],
    );
    expect(s.maxSubtasksOnDoneTask, 5);
  });

  test('cleared days are passed through', () {
    expect(of([], cleared: 3).clearedDays, 3);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/achievements/completion_stats_test.dart`
Expected: FAIL to compile, `completion_stats.dart` does not exist.

- [ ] **Step 3: Write the implementation**

`app/lib/features/achievements/domain/completion_stats.dart`:

```dart
import 'package:nemo/utils/dates.dart';
import 'package:nemo_core/nemo_core.dart';

/// What has been done so far, as the achievements read it.
class CompletionStats {
  const CompletionStats({
    this.totalDone = 0,
    this.onTimeDone = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.clearedDays = 0,
    this.maxSubtasksOnDoneTask = 0,
  });

  /// Worked out from every task and subtask row on the device.
  ///
  /// [clearedDays] comes from outside: a cleared Today leaves no trace in
  /// the rows, so the celebration controller counts it as it happens.
  factory CompletionStats.from({
    required Iterable<Task> tasks,
    required Iterable<Subtask> subtasks,
    required DateTime now,
    int clearedDays = 0,
  }) {
    final done = [
      for (final t in tasks)
        if (t.done && !t.isDeleted) t,
    ];

    var onTime = 0;
    final days = <DateTime>{};
    for (final t in done) {
      final doneAt = t.doneAt;
      if (doneAt == null) continue;
      days.add(startOfDay(DateTime.fromMillisecondsSinceEpoch(doneAt)));
      final dueAt = t.dueAt;
      if (dueAt == null) continue;
      // Without a time of day, anywhere in the due day is on time.
      final inTime = t.dueHasTime
          ? doneAt <= dueAt
          : doneAt <
                dayStartMsFrom(DateTime.fromMillisecondsSinceEpoch(dueAt), 1);
      if (inTime) onTime++;
    }

    final perTask = <String, int>{};
    for (final s in subtasks) {
      if (!s.isDeleted) perTask[s.taskId] = (perTask[s.taskId] ?? 0) + 1;
    }
    var maxSubtasks = 0;
    for (final t in done) {
      final n = perTask[t.id] ?? 0;
      if (n > maxSubtasks) maxSubtasks = n;
    }

    return CompletionStats(
      totalDone: done.length,
      onTimeDone: onTime,
      currentStreak: _currentStreak(days, now),
      bestStreak: _bestStreak(days),
      clearedDays: clearedDays,
      maxSubtasksOnDoneTask: maxSubtasks,
    );
  }

  final int totalDone;

  /// Done tasks finished no later than their due time or due day.
  final int onTimeDone;

  /// Consecutive days with a completion, ending today -- or yesterday, so a
  /// streak is not lost before today's first task is done.
  final int currentStreak;
  final int bestStreak;

  /// Days on which this device saw Today cleared.
  final int clearedDays;

  /// The longest live checklist on a done task.
  final int maxSubtasksOnDoneTask;

  // Days are stepped by calendar date rather than by 24 hours, which is
  // what keeps a daylight saving change from breaking a streak.
  static DateTime _next(DateTime d) => DateTime(d.year, d.month, d.day + 1);
  static DateTime _previous(DateTime d) =>
      DateTime(d.year, d.month, d.day - 1);

  static int _currentStreak(Set<DateTime> days, DateTime now) {
    final today = startOfDay(now);
    var cursor = days.contains(today) ? today : _previous(today);
    var streak = 0;
    while (days.contains(cursor)) {
      streak++;
      cursor = _previous(cursor);
    }
    return streak;
  }

  static int _bestStreak(Set<DateTime> days) {
    final sorted = days.toList()..sort();
    var best = 0;
    var run = 0;
    DateTime? last;
    for (final d in sorted) {
      run = last != null && _next(last) == d ? run + 1 : 1;
      if (run > best) best = run;
      last = d;
    }
    return best;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/achievements/completion_stats_test.dart && TZ=Europe/Berlin flutter test test/features/achievements/completion_stats_test.dart`
Expected: PASS, both runs.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/achievements/domain/completion_stats.dart app/test/features/achievements/completion_stats_test.dart
git commit -m "feat(app): work out completion stats from task rows"
```

---

### Task 2: Achievement catalog

**Files:**
- Create: `app/lib/features/achievements/domain/achievement.dart`
- Modify: `app/lib/l10n/app_en.arb`, `app_de.arb`, `app_it.arb`
- Test: `app/test/features/achievements/achievement_catalog_test.dart`

**Interfaces:**
- Consumes: `CompletionStats` (Task 1); `L` from `package:nemo/l10n/app_localizations.dart`.
- Produces:
  - `class Achievement { const Achievement({required String id, required IconData icon, required int target, required int Function(CompletionStats) value, required String Function(L) title, required String Function(L) description}); }`
  - `class AchievementProgress { const AchievementProgress(Achievement achievement, int value); bool get unlocked; int get shown; double get fraction; }`
  - `final List<Achievement> achievementCatalog`
  - `List<AchievementProgress> progressOf(CompletionStats stats)`

- [ ] **Step 1: Add the strings**

Before the closing `}` of `app/lib/l10n/app_en.arb` (add a comma after the current last entry):

```json
  "achievementFirstDoneTitle": "First step",
  "achievementFirstDoneDescription": "Complete your first task",
  "achievementDone10Title": "Getting going",
  "achievementDone10Description": "Complete 10 tasks",
  "achievementDone100Title": "Centurion",
  "achievementDone100Description": "Complete 100 tasks",
  "achievementDone500Title": "Unstoppable",
  "achievementDone500Description": "Complete 500 tasks",
  "achievementStreak3Title": "On a roll",
  "achievementStreak3Description": "Complete a task 3 days in a row",
  "achievementStreak7Title": "Week warrior",
  "achievementStreak7Description": "Complete a task 7 days in a row",
  "achievementStreak30Title": "Habit formed",
  "achievementStreak30Description": "Complete a task 30 days in a row",
  "achievementClearedTodayTitle": "Clean slate",
  "achievementClearedTodayDescription": "Finish everything due today",
  "achievementOnTime25Title": "Punctual",
  "achievementOnTime25Description": "Complete 25 tasks before they are due",
  "achievementChecklist5Title": "Checklist master",
  "achievementChecklist5Description": "Complete a task with 5 or more subtasks"
```

`app/lib/l10n/app_de.arb`, same place:

```json
  "achievementFirstDoneTitle": "Erster Schritt",
  "achievementFirstDoneDescription": "Erledige deine erste Aufgabe",
  "achievementDone10Title": "In Fahrt",
  "achievementDone10Description": "Erledige 10 Aufgaben",
  "achievementDone100Title": "Hundert geschafft",
  "achievementDone100Description": "Erledige 100 Aufgaben",
  "achievementDone500Title": "Unaufhaltsam",
  "achievementDone500Description": "Erledige 500 Aufgaben",
  "achievementStreak3Title": "Am Laufen",
  "achievementStreak3Description": "Erledige 3 Tage in Folge eine Aufgabe",
  "achievementStreak7Title": "Wochenheld",
  "achievementStreak7Description": "Erledige 7 Tage in Folge eine Aufgabe",
  "achievementStreak30Title": "Gewohnheit",
  "achievementStreak30Description": "Erledige 30 Tage in Folge eine Aufgabe",
  "achievementClearedTodayTitle": "Reiner Tisch",
  "achievementClearedTodayDescription": "Erledige alles, was heute fällig ist",
  "achievementOnTime25Title": "Pünktlich",
  "achievementOnTime25Description": "Erledige 25 Aufgaben vor ihrer Fälligkeit",
  "achievementChecklist5Title": "Checklisten-Profi",
  "achievementChecklist5Description": "Erledige eine Aufgabe mit 5 oder mehr Unteraufgaben"
```

`app/lib/l10n/app_it.arb`, same place:

```json
  "achievementFirstDoneTitle": "Primo passo",
  "achievementFirstDoneDescription": "Completa la tua prima attività",
  "achievementDone10Title": "Si parte",
  "achievementDone10Description": "Completa 10 attività",
  "achievementDone100Title": "Centurione",
  "achievementDone100Description": "Completa 100 attività",
  "achievementDone500Title": "Inarrestabile",
  "achievementDone500Description": "Completa 500 attività",
  "achievementStreak3Title": "In serie",
  "achievementStreak3Description": "Completa un'attività per 3 giorni di fila",
  "achievementStreak7Title": "Guerriero della settimana",
  "achievementStreak7Description": "Completa un'attività per 7 giorni di fila",
  "achievementStreak30Title": "Abitudine presa",
  "achievementStreak30Description": "Completa un'attività per 30 giorni di fila",
  "achievementClearedTodayTitle": "Tabula rasa",
  "achievementClearedTodayDescription": "Completa tutto ciò che scade oggi",
  "achievementOnTime25Title": "Puntuale",
  "achievementOnTime25Description": "Completa 25 attività prima della scadenza",
  "achievementChecklist5Title": "Maestro delle checklist",
  "achievementChecklist5Description": "Completa un'attività con 5 o più sottoattività"
```

Run: `flutter gen-l10n`
Expected: no output, `lib/l10n/app_localizations*.dart` updated.

- [ ] **Step 2: Write the failing test**

`app/test/features/achievements/achievement_catalog_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/achievements/domain/achievement.dart';
import 'package:nemo/features/achievements/domain/completion_stats.dart';
import 'package:nemo/l10n/app_localizations.dart';

void main() {
  test('ids are the shipped ones, unique and in order', () {
    expect(achievementCatalog.map((a) => a.id), [
      'first_done',
      'done_10',
      'done_100',
      'done_500',
      'streak_3',
      'streak_7',
      'streak_30',
      'cleared_today',
      'on_time_25',
      'checklist_5',
    ]);
  });

  test('every achievement has words in every language', () async {
    for (final locale in L.supportedLocales) {
      final l = await L.delegate.load(locale);
      for (final a in achievementCatalog) {
        expect(a.title(l), isNotEmpty, reason: '${a.id} $locale');
        expect(a.description(l), isNotEmpty, reason: '${a.id} $locale');
      }
    }
  });

  test('unlocks at the target and caps progress there', () {
    final ten = achievementCatalog.firstWhere((a) => a.id == 'done_10');
    expect(AchievementProgress(ten, 9).unlocked, isFalse);
    expect(AchievementProgress(ten, 9).fraction, closeTo(0.9, 1e-9));
    expect(AchievementProgress(ten, 10).unlocked, isTrue);
    expect(AchievementProgress(ten, 25).shown, 10);
    expect(AchievementProgress(ten, 25).fraction, 1.0);
  });

  test('progressOf reads each stat', () {
    final unlocked = progressOf(
      const CompletionStats(
        totalDone: 1,
        bestStreak: 3,
        clearedDays: 1,
        onTimeDone: 25,
        maxSubtasksOnDoneTask: 5,
      ),
    ).where((p) => p.unlocked).map((p) => p.achievement.id);
    expect(unlocked, [
      'first_done',
      'streak_3',
      'cleared_today',
      'on_time_25',
      'checklist_5',
    ]);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/achievements/achievement_catalog_test.dart`
Expected: FAIL to compile, `achievement.dart` does not exist.

- [ ] **Step 4: Write the implementation**

`app/lib/features/achievements/domain/achievement.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:nemo/features/achievements/domain/completion_stats.dart';
import 'package:nemo/l10n/app_localizations.dart';

/// Something to reach, read off [CompletionStats].
class Achievement {
  const Achievement({
    required this.id,
    required this.icon,
    required this.target,
    required this.value,
    required this.title,
    required this.description,
  });

  /// Stored in the set of achievements already celebrated; never renamed.
  final String id;
  final IconData icon;
  final int target;
  final int Function(CompletionStats stats) value;
  final String Function(L l) title;
  final String Function(L l) description;
}

/// How far along one achievement is.
class AchievementProgress {
  const AchievementProgress(this.achievement, this.value);

  final Achievement achievement;
  final int value;

  bool get unlocked => value >= achievement.target;

  /// [value], capped at the target, for "7 / 10".
  int get shown => value < achievement.target ? value : achievement.target;

  double get fraction => shown / achievement.target;
}

/// Every achievement, in the order the achievements screen shows them.
///
/// Streaks read the best streak, so one reached stays reached.
final List<Achievement> achievementCatalog = [
  Achievement(
    id: 'first_done',
    icon: Icons.check_circle_outline_rounded,
    target: 1,
    value: (s) => s.totalDone,
    title: (l) => l.achievementFirstDoneTitle,
    description: (l) => l.achievementFirstDoneDescription,
  ),
  Achievement(
    id: 'done_10',
    icon: Icons.trending_up_rounded,
    target: 10,
    value: (s) => s.totalDone,
    title: (l) => l.achievementDone10Title,
    description: (l) => l.achievementDone10Description,
  ),
  Achievement(
    id: 'done_100',
    icon: Icons.military_tech_outlined,
    target: 100,
    value: (s) => s.totalDone,
    title: (l) => l.achievementDone100Title,
    description: (l) => l.achievementDone100Description,
  ),
  Achievement(
    id: 'done_500',
    icon: Icons.rocket_launch_outlined,
    target: 500,
    value: (s) => s.totalDone,
    title: (l) => l.achievementDone500Title,
    description: (l) => l.achievementDone500Description,
  ),
  Achievement(
    id: 'streak_3',
    icon: Icons.local_fire_department_outlined,
    target: 3,
    value: (s) => s.bestStreak,
    title: (l) => l.achievementStreak3Title,
    description: (l) => l.achievementStreak3Description,
  ),
  Achievement(
    id: 'streak_7',
    icon: Icons.whatshot_outlined,
    target: 7,
    value: (s) => s.bestStreak,
    title: (l) => l.achievementStreak7Title,
    description: (l) => l.achievementStreak7Description,
  ),
  Achievement(
    id: 'streak_30',
    icon: Icons.event_available_outlined,
    target: 30,
    value: (s) => s.bestStreak,
    title: (l) => l.achievementStreak30Title,
    description: (l) => l.achievementStreak30Description,
  ),
  Achievement(
    id: 'cleared_today',
    icon: Icons.wb_sunny_outlined,
    target: 1,
    value: (s) => s.clearedDays,
    title: (l) => l.achievementClearedTodayTitle,
    description: (l) => l.achievementClearedTodayDescription,
  ),
  Achievement(
    id: 'on_time_25',
    icon: Icons.schedule_rounded,
    target: 25,
    value: (s) => s.onTimeDone,
    title: (l) => l.achievementOnTime25Title,
    description: (l) => l.achievementOnTime25Description,
  ),
  Achievement(
    id: 'checklist_5',
    icon: Icons.checklist_rounded,
    target: 5,
    value: (s) => s.maxSubtasksOnDoneTask,
    title: (l) => l.achievementChecklist5Title,
    description: (l) => l.achievementChecklist5Description,
  ),
];

List<AchievementProgress> progressOf(CompletionStats stats) => [
  for (final a in achievementCatalog) AchievementProgress(a, a.value(stats)),
];
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/achievements/achievement_catalog_test.dart test/l10n/translations_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/achievements/domain/achievement.dart app/lib/l10n app/test/features/achievements/achievement_catalog_test.dart
git commit -m "feat(app): catalog of ten achievements"
```

---

### Task 3: Achievements repository and providers

**Files:**
- Modify: `app/lib/core/db/kv_store.dart` (the `KvKeys` class)
- Create: `app/lib/features/achievements/data/achievements_repository.dart`
- Create: `app/lib/features/achievements/ui/achievements_providers.dart` (+ generated `.g.dart`)
- Test: `app/test/features/achievements/achievements_repository_test.dart`

**Interfaces:**
- Consumes: `CompletionStats` (Task 1), `progressOf`/`AchievementProgress` (Task 2), `AppDatabase`, `KvStore`, `appDatabaseProvider`, `nowProvider`, `dayStartMsFrom`, `startOfDay`.
- Produces:
  - `KvKeys.achievementsSeen = 'achievements_seen'`, `KvKeys.clearedDays = 'cleared_days'`, `KvKeys.lastClearedDay = 'last_cleared_day'`
  - `class AchievementsRepository { AchievementsRepository(AppDatabase db, {DateTime Function()? now}); Future<CompletionStats> stats(); Future<List<AchievementProgress>> progress(); Stream<CompletionStats> watchStats(); Future<bool> todayIsClear(); Future<void> recordClearedDay(); Future<Set<String>?> seen(); Future<void> markSeen(Iterable<String> ids); }`
  - `final achievementsRepositoryProvider = Provider<AchievementsRepository>`
  - generated `completionStatsProvider` (`AsyncValue<CompletionStats>`)

- [ ] **Step 1: Add the keys**

In `app/lib/core/db/kv_store.dart`, inside `abstract final class KvKeys`, after `serverPhotos`:

```dart

  /// JSON list of achievement ids this device has already celebrated, or
  /// quietly recorded as reached. Unset until the first check.
  static const achievementsSeen = 'achievements_seen';

  /// How many days this device saw Today cleared, and the last such day as
  /// `yyyy-mm-dd`, so one day is counted once.
  static const clearedDays = 'cleared_days';
  static const lastClearedDay = 'last_cleared_day';
```

- [ ] **Step 2: Write the failing test**

`app/test/features/achievements/achievements_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/features/achievements/data/achievements_repository.dart';
import 'package:nemo/features/lists/data/lists_repository.dart';
import 'package:nemo/features/tasks/data/subtasks_repository.dart';
import 'package:nemo/features/tasks/data/tasks_repository.dart';
import 'package:nemo/utils/dates.dart';

import '../../support/test_db.dart';

void main() {
  late AppDatabase db;
  late TasksRepository tasks;
  late SubtasksRepository subtasks;
  late AchievementsRepository repo;
  late String inbox;

  setUp(() async {
    db = testDatabase();
    final clock = testClock();
    final ids = sequentialIds();
    inbox = (await ListsRepository(db, clock, ids).ensureInbox()).id;
    tasks = TasksRepository(
      db,
      clock,
      ids,
      reminders: const NoopReminderScheduler(),
      now: () => testNow,
    );
    subtasks = SubtasksRepository(db, clock, ids);
    repo = AchievementsRepository(db, now: () => testNow);
  });
  tearDown(() => db.close());

  test('stats count done tasks and their checklists', () async {
    final a = await tasks.create(listId: inbox, title: 'A');
    for (var i = 0; i < 5; i++) {
      await subtasks.add(a.id, 'step $i');
    }
    final b = await tasks.create(listId: inbox, title: 'B');
    await tasks.setDone(a.id, done: true);
    await tasks.setDone(b.id, done: true);
    await tasks.delete(b.id);

    final s = await repo.stats();
    expect(s.totalDone, 1);
    expect(s.maxSubtasksOnDoneTask, 5);
    expect(s.currentStreak, 1);
  });

  test('Today is clear once nothing due today or earlier is open', () async {
    await tasks.create(listId: inbox, title: 'Someday');
    expect(await repo.todayIsClear(), isTrue, reason: 'undated is not Today');
    final due = await tasks.create(
      listId: inbox,
      title: 'Due',
      dueAt: dayStartMs(testNow),
    );
    await tasks.create(
      listId: inbox,
      title: 'Tomorrow',
      dueAt: dayStartMsFrom(testNow, 1),
    );
    expect(await repo.todayIsClear(), isFalse);
    await tasks.setDone(due.id, done: true);
    expect(await repo.todayIsClear(), isTrue);
  });

  test('a cleared day is counted once', () async {
    await repo.recordClearedDay();
    await repo.recordClearedDay();
    expect((await repo.stats()).clearedDays, 1);
  });

  test('the celebrated set starts unset and grows', () async {
    expect(await repo.seen(), isNull);
    await repo.markSeen(['first_done']);
    await repo.markSeen(['done_10', 'first_done']);
    expect(await repo.seen(), {'first_done', 'done_10'});
  });

  test('a damaged celebrated set reads as unset', () async {
    await KvStore(db).set(KvKeys.achievementsSeen, 'not json');
    expect(await repo.seen(), isNull);
  });

  test('stats follow the database', () async {
    final a = await tasks.create(listId: inbox, title: 'A');
    final totals = repo.watchStats().map((s) => s.totalDone);
    final reached = expectLater(totals, emitsThrough(1));
    await tasks.setDone(a.id, done: true);
    await reached;
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/achievements/achievements_repository_test.dart`
Expected: FAIL to compile, `achievements_repository.dart` does not exist.

- [ ] **Step 4: Write the repository**

`app/lib/features/achievements/data/achievements_repository.dart`:

```dart
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/features/achievements/domain/achievement.dart';
import 'package:nemo/features/achievements/domain/completion_stats.dart';
import 'package:nemo/utils/dates.dart';

/// Achievement progress, worked out from the rows on this device, plus the
/// little the rows cannot tell: cleared days and what was celebrated.
class AchievementsRepository {
  AchievementsRepository(this._db, {DateTime Function()? now})
    : _kv = KvStore(_db),
      _now = now ?? DateTime.now;

  final AppDatabase _db;
  final KvStore _kv;
  final DateTime Function() _now;

  Future<CompletionStats> stats() async {
    final tasks = await (_db.select(
      _db.tasks,
    )..where((t) => t.done.equals(true) & t.deletedAt.isNull())).get();
    final subtasks = await (_db.select(
      _db.subtasks,
    )..where((t) => t.deletedAt.isNull())).get();
    final cleared = int.tryParse(await _kv.get(KvKeys.clearedDays) ?? '');
    return CompletionStats.from(
      tasks: tasks,
      subtasks: subtasks,
      now: _now(),
      clearedDays: cleared ?? 0,
    );
  }

  Future<List<AchievementProgress>> progress() async =>
      progressOf(await stats());

  /// Recomputed whenever a task, a subtask or the key-value store changes.
  Stream<CompletionStats> watchStats() => _db
      .customSelect('SELECT 1', readsFrom: {_db.tasks, _db.subtasks, _db.kv})
      .watch()
      .asyncMap((_) => stats());

  /// Whether nothing Today shows as open is left: nothing due today or
  /// earlier, in a list that still exists, is still to do.
  Future<bool> todayIsClear() async {
    final tomorrow = dayStartMsFrom(_now(), 1);
    final query =
        _db.select(_db.tasks).join([
            innerJoin(
              _db.lists,
              _db.lists.id.equalsExp(_db.tasks.listId),
              useColumns: false,
            ),
          ])
          ..where(
            _db.tasks.deletedAt.isNull() &
                _db.lists.deletedAt.isNull() &
                _db.tasks.done.equals(false) &
                _db.tasks.dueAt.isNotNull() &
                _db.tasks.dueAt.isSmallerThanValue(tomorrow),
          )
          ..limit(1);
    return (await query.get()).isEmpty;
  }

  /// Counts today as a cleared day, once however often it is cleared.
  Future<void> recordClearedDay() async {
    final day = startOfDay(_now()).toIso8601String().substring(0, 10);
    if (await _kv.get(KvKeys.lastClearedDay) == day) return;
    final count = int.tryParse(await _kv.get(KvKeys.clearedDays) ?? '') ?? 0;
    await _kv.set(KvKeys.clearedDays, '${count + 1}');
    await _kv.set(KvKeys.lastClearedDay, day);
  }

  /// Ids already celebrated or quietly recorded; null when never written or
  /// unreadable, which callers treat as "record, do not celebrate".
  Future<Set<String>?> seen() async {
    final raw = await _kv.get(KvKeys.achievementsSeen);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return {...decoded.whereType<String>()};
    } on FormatException {
      // Rewritten whole by the next markSeen.
    }
    return null;
  }

  Future<void> markSeen(Iterable<String> ids) async {
    final all = {...?await seen(), ...ids}.toList()..sort();
    await _kv.set(KvKeys.achievementsSeen, jsonEncode(all));
  }
}
```

- [ ] **Step 5: Write the providers**

`app/lib/features/achievements/ui/achievements_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/features/achievements/data/achievements_repository.dart';
import 'package:nemo/features/achievements/domain/completion_stats.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'achievements_providers.g.dart';

final achievementsRepositoryProvider = Provider<AchievementsRepository>(
  (ref) => AchievementsRepository(
    ref.watch(appDatabaseProvider),
    now: ref.watch(nowProvider),
  ),
);

@riverpod
Stream<CompletionStats> completionStats(Ref ref) =>
    ref.watch(achievementsRepositoryProvider).watchStats();
```

Run: `dart run build_runner build`
Expected: finishes with `Built with build_runner`, creates `achievements_providers.g.dart`.

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/features/achievements/`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add app/lib/core/db/kv_store.dart app/lib/features/achievements app/test/features/achievements/achievements_repository_test.dart
git commit -m "feat(app): read achievement progress from the local database"
```

---

### Task 4: Achievements screen and route

**Files:**
- Create: `app/lib/features/achievements/ui/achievements_screen.dart`
- Modify: `app/lib/router.dart`, the three `.arb` files
- Test: `app/test/features/achievements/achievements_screen_test.dart`

**Interfaces:**
- Consumes: `completionStatsProvider` (Task 3), `progressOf`, `achievementCatalog`, `AchievementProgress` (Task 2), `MaxWidth`.
- Produces: `Routes.achievements = '/settings/achievements'`; `class AchievementsScreen extends ConsumerWidget`; each card keyed `Key('achievement-<id>')`; strings `achievementsTitle`, `achievementsUnlockedCount(int unlocked, int total)`, `achievementsProgress(int value, int target)`, `achievementsUnlocked`, `achievementsStreak(int count)`.

- [ ] **Step 1: Add the strings**

`app_en.arb`:

```json
  "achievementsTitle": "Achievements",
  "achievementsUnlockedCount": "{unlocked} of {total} unlocked",
  "@achievementsUnlockedCount": {
    "placeholders": {"unlocked": {"type": "int"}, "total": {"type": "int"}}
  },
  "achievementsProgress": "{value} / {target}",
  "@achievementsProgress": {
    "placeholders": {"value": {"type": "int"}, "target": {"type": "int"}}
  },
  "achievementsUnlocked": "Unlocked",
  "achievementsStreak": "{count, plural, =1{1-day streak} other{{count}-day streak}}",
  "@achievementsStreak": {
    "placeholders": {"count": {"type": "int"}}
  }
```

`app_de.arb`:

```json
  "achievementsTitle": "Erfolge",
  "achievementsUnlockedCount": "{unlocked} von {total} freigeschaltet",
  "achievementsProgress": "{value} / {target}",
  "achievementsUnlocked": "Freigeschaltet",
  "achievementsStreak": "{count, plural, =1{1 Tag in Folge} other{{count} Tage in Folge}}"
```

`app_it.arb`:

```json
  "achievementsTitle": "Traguardi",
  "achievementsUnlockedCount": "{unlocked} di {total} sbloccati",
  "achievementsProgress": "{value} / {target}",
  "achievementsUnlocked": "Sbloccato",
  "achievementsStreak": "{count, plural, =1{1 giorno di fila} other{{count} giorni di fila}}"
```

Run: `flutter gen-l10n`

- [ ] **Step 2: Write the failing test**

`app/test/features/achievements/achievements_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/features/tasks/data/tasks_repository.dart';
import 'package:nemo/router.dart';

import '../../support/pump_app.dart';
import '../../support/test_db.dart';

void main() {
  appTest('shows unlocked and locked achievements', (tester) async {
    await pumpApp(
      tester,
      initialLocation: Routes.achievements,
      seed: (db, inbox) async {
        final tasks = TasksRepository(
          db,
          testClock('seed'),
          sequentialIds('task'),
          reminders: const NoopReminderScheduler(),
          now: () => testNow,
        );
        final t = await tasks.create(listId: inbox.id, title: 'Done');
        await tasks.setDone(t.id, done: true);
      },
    );

    expect(find.text('Achievements'), findsOneWidget);
    expect(find.text('1 of 10 unlocked'), findsOneWidget);
    expect(find.text('1-day streak'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('achievement-first_done')),
        matching: find.text('Unlocked'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('achievement-done_10')),
        matching: find.text('1 / 10'),
      ),
      findsOneWidget,
    );
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/achievements/achievements_screen_test.dart`
Expected: FAIL to compile, `Routes.achievements` is not defined.

- [ ] **Step 4: Add the route**

In `app/lib/router.dart`:
- import `package:nemo/features/achievements/ui/achievements_screen.dart`;
- in `Routes`, after `account`: `static const achievements = '/settings/achievements';`
- in the `Routes.settings` `GoRoute`'s `routes:` list, after the `account` route:

```dart
          GoRoute(
            path: 'achievements',
            pageBuilder: (_, s) =>
                fadeThroughPage(child: const AchievementsScreen(), state: s),
          ),
```

- [ ] **Step 5: Write the screen**

`app/lib/features/achievements/ui/achievements_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/widgets/max_width.dart';
import 'package:nemo/features/achievements/domain/achievement.dart';
import 'package:nemo/features/achievements/ui/achievements_providers.dart';
import 'package:nemo/l10n/app_localizations.dart';

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final stats = ref.watch(completionStatsProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(l.achievementsTitle)),
      body: stats == null
          ? const Center(child: CircularProgressIndicator())
          : MaxWidth(
              child: Builder(
                builder: (context) {
                  final items = progressOf(stats);
                  final unlocked = items.where((p) => p.unlocked).length;
                  final text = Theme.of(context).textTheme;
                  final scheme = Theme.of(context).colorScheme;
                  return CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        sliver: SliverToBoxAdapter(
                          child: Wrap(
                            spacing: 16,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                l.achievementsUnlockedCount(
                                  unlocked,
                                  items.length,
                                ),
                                style: text.titleMedium,
                              ),
                              if (stats.currentStreak > 0)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.local_fire_department_rounded,
                                      size: 20,
                                      color: scheme.tertiary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      l.achievementsStreak(
                                        stats.currentStreak,
                                      ),
                                      style: text.bodyMedium,
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 220,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 0.8,
                              ),
                          delegate: SliverChildBuilderDelegate(
                            (context, i) => AchievementCard(progress: items[i]),
                            childCount: items.length,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
    );
  }
}

/// One achievement: full colour once reached, muted with progress before.
class AchievementCard extends StatelessWidget {
  const AchievementCard({required this.progress, super.key});

  final AchievementProgress progress;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final a = progress.achievement;
    final on = progress.unlocked;
    final status = on
        ? l.achievementsUnlocked
        : l.achievementsProgress(progress.shown, a.target);
    return Semantics(
      key: Key('achievement-${a.id}'),
      label: '${a.title(l)}. ${a.description(l)}. $status',
      excludeSemantics: true,
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: on ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                a.icon,
                size: 36,
                color: on
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 8),
              Text(
                a.title(l),
                style: text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: on ? scheme.onPrimaryContainer : scheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Expanded(
                child: Text(
                  a.description(l),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(
                    color: on
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (!on) ...[
                LinearProgressIndicator(
                  value: progress.fraction,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 4),
              ],
              Text(status, style: text.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/features/achievements/ test/l10n/translations_test.dart`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add app/lib/router.dart app/lib/features/achievements/ui/achievements_screen.dart app/lib/l10n app/test/features/achievements/achievements_screen_test.dart
git commit -m "feat(app): achievements screen"
```

---

### Task 5: Settings switches

**Files:**
- Modify: `app/lib/core/db/kv_store.dart`, `app/lib/core/providers.dart`, `app/lib/features/settings/ui/settings_controller.dart` (+ `.g.dart`), `app/lib/features/settings/ui/settings_screen.dart`, `app/test/support/pump_app.dart`, the three `.arb` files
- Create: `app/lib/features/celebrations/ui/celebration_settings_section.dart`
- Test: `app/test/features/settings/settings_screen_test.dart`

**Interfaces:**
- Consumes: `Routes.achievements`, `AchievementsScreen` (Task 4), `completionStatsProvider` (Task 3), `progressOf`, `achievementCatalog` (Task 2).
- Produces:
  - `KvKeys.celebrations = 'celebrations'`, `KvKeys.celebrationSound = 'celebration_sound'`, `KvKeys.achievements = 'achievements'`
  - `AppBootstrap.celebrations` (bool, default true), `.celebrationSound` (default false), `.achievements` (default true)
  - generated `celebrationsEnabledProvider`, `celebrationSoundEnabledProvider`, `achievementsEnabledProvider` (all `bool`), each notifier with `Future<void> set({required bool enabled})`
  - `class CelebrationSettingsSection extends ConsumerWidget`; keys `celebrations-switch`, `celebration-sound-switch`, `achievements-switch`, `achievements-tile`
  - `pumpApp(..., bool celebrate = false)`: when false, the test app starts with Celebrations and Achievements off

- [ ] **Step 1: Add the keys and bootstrap fields**

In `KvKeys`, after `lastClearedDay`:

```dart

  /// Per-device celebration switches: `"true"` or `"false"`; unset is the
  /// default (celebrations and achievements on, sound off).
  static const celebrations = 'celebrations';
  static const celebrationSound = 'celebration_sound';
  static const achievements = 'achievements';
```

In `app/lib/core/providers.dart`, `AppBootstrap`: add constructor parameters `this.celebrations = true, this.celebrationSound = false, this.achievements = true,` after `this.serverVersion,`; add fields after `serverVersion`:

```dart

  /// Confetti, animations and haptics when a task is completed.
  final bool celebrations;

  /// A sound for the big moments; off unless chosen.
  final bool celebrationSound;

  /// Achievements, their banners and the Settings tile.
  final bool achievements;
```

and in `load`, add to the returned `AppBootstrap(...)` after `serverVersion:`:

```dart
      celebrations: await kv.get(KvKeys.celebrations) != 'false',
      celebrationSound: await kv.get(KvKeys.celebrationSound) == 'true',
      achievements: await kv.get(KvKeys.achievements) != 'false',
```

- [ ] **Step 2: Add the strings**

`app_en.arb`:

```json
  "settingsCelebrations": "Celebrations & achievements",
  "settingsCelebrationsEnabled": "Celebrations",
  "settingsCelebrationsEnabledHint": "Confetti, animations and haptics when you complete tasks",
  "settingsCelebrationSound": "Sound",
  "settingsCelebrationSoundHint": "Play a sound for big moments",
  "settingsAchievements": "Achievements",
  "settingsAchievementsHint": "Show achievements and unlock banners",
  "achievementsView": "View achievements"
```

`app_de.arb`:

```json
  "settingsCelebrations": "Feiern & Erfolge",
  "settingsCelebrationsEnabled": "Feiern",
  "settingsCelebrationsEnabledHint": "Konfetti, Animationen und Vibration beim Erledigen von Aufgaben",
  "settingsCelebrationSound": "Ton",
  "settingsCelebrationSoundHint": "Bei großen Momenten einen Ton abspielen",
  "settingsAchievements": "Erfolge",
  "settingsAchievementsHint": "Erfolge und Freischalt-Hinweise anzeigen",
  "achievementsView": "Erfolge ansehen"
```

`app_it.arb`:

```json
  "settingsCelebrations": "Festeggiamenti e traguardi",
  "settingsCelebrationsEnabled": "Festeggiamenti",
  "settingsCelebrationsEnabledHint": "Coriandoli, animazioni e vibrazione quando completi le attività",
  "settingsCelebrationSound": "Suono",
  "settingsCelebrationSoundHint": "Riproduci un suono nei momenti importanti",
  "settingsAchievements": "Traguardi",
  "settingsAchievementsHint": "Mostra traguardi e avvisi di sblocco",
  "achievementsView": "Vedi traguardi"
```

Run: `flutter gen-l10n`

- [ ] **Step 3: Let tests choose celebrations**

In `app/test/support/pump_app.dart`:
- add `import 'package:nemo/core/db/kv_store.dart';`
- add a parameter after `PhotoStore? photoStore,`:

```dart
  // Celebrations are on in the app. Most tests tick tasks off and look at
  // what follows, which a banner over the app bar would get in the way of,
  // so they start off unless a test is about them.
  bool celebrate = false,
```

- replace `await seed?.call(db, inbox);` with:

```dart
  if (!celebrate) {
    await KvStore(db).set(KvKeys.celebrations, 'false');
    await KvStore(db).set(KvKeys.achievements, 'false');
  }
  await seed?.call(db, inbox);
```

- [ ] **Step 4: Write the failing tests**

Append inside `main()` of `app/test/features/settings/settings_screen_test.dart` (add imports `package:nemo/features/achievements/ui/achievements_screen.dart` at the top):

```dart
  appTest('celebrations start on, sound off, achievements on', (tester) async {
    await pumpApp(tester, initialLocation: Routes.settings, celebrate: true);
    bool value(String key) =>
        tester.widget<SwitchListTile>(find.byKey(Key(key))).value;
    expect(value('celebrations-switch'), isTrue);
    expect(value('celebration-sound-switch'), isFalse);
    expect(value('achievements-switch'), isTrue);
    expect(find.byKey(const Key('achievements-tile')), findsOneWidget);
    expect(find.text('0 of 10 unlocked'), findsOneWidget);
  });

  appTest('switches persist, and sound needs celebrations', (tester) async {
    final app = await pumpApp(
      tester,
      initialLocation: Routes.settings,
      celebrate: true,
    );
    final kv = KvStore(app.db);
    SwitchListTile tile(String key) =>
        tester.widget<SwitchListTile>(find.byKey(Key(key)));

    await tester.tap(find.byKey(const Key('celebration-sound-switch')));
    await tester.pumpAndSettle();
    expect(await kv.get(KvKeys.celebrationSound), 'true');

    await tester.tap(find.byKey(const Key('celebrations-switch')));
    await tester.pumpAndSettle();
    expect(await kv.get(KvKeys.celebrations), 'false');
    expect(tile('celebration-sound-switch').onChanged, isNull);

    await tester.tap(find.byKey(const Key('achievements-switch')));
    await tester.pumpAndSettle();
    expect(await kv.get(KvKeys.achievements), 'false');
    expect(find.byKey(const Key('achievements-tile')), findsNothing);
  });

  appTest('stored switches are read at start', (tester) async {
    await pumpApp(
      tester,
      initialLocation: Routes.settings,
      celebrate: true,
      seed: (db, _) => KvStore(db).set(KvKeys.celebrations, 'false'),
    );
    expect(
      tester
          .widget<SwitchListTile>(find.byKey(const Key('celebrations-switch')))
          .value,
      isFalse,
    );
  });

  appTest('the achievements tile opens the screen', (tester) async {
    await pumpApp(tester, initialLocation: Routes.settings, celebrate: true);
    await tester.tap(find.byKey(const Key('achievements-tile')));
    await tester.pumpAndSettle();
    expect(find.byType(AchievementsScreen), findsOneWidget);
  });
```

- [ ] **Step 5: Run tests to verify they fail**

Run: `flutter test test/features/settings/settings_screen_test.dart`
Expected: the four new tests FAIL (no widget with key `celebrations-switch`); the theme test still passes.

- [ ] **Step 6: Add the switch notifiers**

Append to `app/lib/features/settings/ui/settings_controller.dart`:

```dart

/// Confetti, animations and haptics on completing a task.
@Riverpod(keepAlive: true)
class CelebrationsEnabled extends _$CelebrationsEnabled {
  @override
  bool build() => ref.watch(bootstrapProvider).celebrations;

  Future<void> set({required bool enabled}) async {
    state = enabled;
    await ref.read(kvStoreProvider).set(KvKeys.celebrations, '$enabled');
  }
}

/// A sound for a cleared day or an unlocked achievement.
@Riverpod(keepAlive: true)
class CelebrationSoundEnabled extends _$CelebrationSoundEnabled {
  @override
  bool build() => ref.watch(bootstrapProvider).celebrationSound;

  Future<void> set({required bool enabled}) async {
    state = enabled;
    await ref.read(kvStoreProvider).set(KvKeys.celebrationSound, '$enabled');
  }
}

/// Achievements, their unlock banners and their Settings tile.
@Riverpod(keepAlive: true)
class AchievementsEnabled extends _$AchievementsEnabled {
  @override
  bool build() => ref.watch(bootstrapProvider).achievements;

  Future<void> set({required bool enabled}) async {
    state = enabled;
    await ref.read(kvStoreProvider).set(KvKeys.achievements, '$enabled');
  }
}
```

Run: `dart run build_runner build`

- [ ] **Step 7: Write the section**

`app/lib/features/celebrations/ui/celebration_settings_section.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/core/widgets/section_header.dart';
import 'package:nemo/features/achievements/domain/achievement.dart';
import 'package:nemo/features/achievements/ui/achievements_providers.dart';
import 'package:nemo/features/settings/ui/settings_controller.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/router.dart';

/// The switches that make nemo cheer, or keep it quiet and professional.
class CelebrationSettingsSection extends ConsumerWidget {
  const CelebrationSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final celebrate = ref.watch(celebrationsEnabledProvider);
    final sound = ref.watch(celebrationSoundEnabledProvider);
    final showAchievements = ref.watch(achievementsEnabledProvider);
    final stats = showAchievements
        ? ref.watch(completionStatsProvider).value
        : null;
    final unlocked = stats == null
        ? null
        : progressOf(stats).where((p) => p.unlocked).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: l.settingsCelebrations),
        SwitchListTile(
          key: const Key('celebrations-switch'),
          secondary: const Icon(Icons.celebration_outlined),
          title: Text(l.settingsCelebrationsEnabled),
          subtitle: Text(l.settingsCelebrationsEnabledHint),
          value: celebrate,
          onChanged: (v) =>
              ref.read(celebrationsEnabledProvider.notifier).set(enabled: v),
        ),
        SwitchListTile(
          key: const Key('celebration-sound-switch'),
          secondary: const Icon(Icons.volume_up_outlined),
          title: Text(l.settingsCelebrationSound),
          subtitle: Text(l.settingsCelebrationSoundHint),
          value: sound,
          // Sound belongs to celebrating; without it there is nothing to
          // play along to.
          onChanged: celebrate
              ? (v) => ref
                    .read(celebrationSoundEnabledProvider.notifier)
                    .set(enabled: v)
              : null,
        ),
        SwitchListTile(
          key: const Key('achievements-switch'),
          secondary: const Icon(Icons.emoji_events_outlined),
          title: Text(l.settingsAchievements),
          subtitle: Text(l.settingsAchievementsHint),
          value: showAchievements,
          onChanged: (v) =>
              ref.read(achievementsEnabledProvider.notifier).set(enabled: v),
        ),
        if (showAchievements)
          ListTile(
            key: const Key('achievements-tile'),
            leading: const SizedBox(width: 24),
            title: Text(l.achievementsView),
            subtitle: unlocked == null
                ? null
                : Text(
                    l.achievementsUnlockedCount(
                      unlocked,
                      achievementCatalog.length,
                    ),
                  ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.push(Routes.achievements),
          ),
      ],
    );
  }
}
```

In `app/lib/features/settings/ui/settings_screen.dart`, import the section and insert `const CelebrationSettingsSection(),` directly after the `Padding` that holds the theme `SegmentedButton` (before `const SyncSettingsSection(),`).

- [ ] **Step 8: Run tests to verify they pass**

Run: `flutter test test/features/settings/ test/l10n/translations_test.dart`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add app/lib/core app/lib/features/settings app/lib/features/celebrations app/lib/l10n app/test/support/pump_app.dart app/test/features/settings/settings_screen_test.dart
git commit -m "feat(app): settings to turn celebrations, sound and achievements off"
```

---

### Task 6: Celebration sound

**Files:**
- Modify: `app/pubspec.yaml`, `app/test/support/pump_app.dart`
- Create: `app/assets/sounds/celebrate.mp3`, `app/assets/sounds/LICENSE.txt`, `app/lib/features/celebrations/data/celebration_sound.dart`, `app/test/support/fake_celebrations.dart`

**Interfaces:**
- Produces: `abstract interface class CelebrationSound { Future<void> play(); }`; `class AssetCelebrationSound implements CelebrationSound { Future<void> dispose(); }`; `final celebrationSoundProvider = Provider<CelebrationSound>`; `class RecordingCelebrationSound implements CelebrationSound { int plays; }` (test support); `pumpApp(..., CelebrationSound? sound)`.

- [ ] **Step 1: Add the dependency**

Run (from `app/`): `flutter pub add audioplayers:^6.8.1`
Expected: `+ audioplayers 6.8.1` and `pubspec.yaml` lists `audioplayers: ^6.8.1` in alphabetical order.

- [ ] **Step 2: Make the sound**

No third-party recording is shipped: the sound is a four-note rising chime (C5 E5 G5 C6) generated here, so its licence is ours to give.

```bash
mkdir -p assets/sounds
ffmpeg -y -f lavfi -i "aevalsrc='0.22*(sin(2*PI*523.25*t)*exp(-7*t)+gte(t,0.11)*sin(2*PI*659.25*t)*exp(-7*(t-0.11))+gte(t,0.22)*sin(2*PI*783.99*t)*exp(-7*(t-0.22))+gte(t,0.33)*sin(2*PI*1046.50*t)*exp(-4*(t-0.33)))':s=44100:d=1.3" -af "afade=t=out:st=1.0:d=0.3" -ac 1 -c:a libmp3lame -b:a 96k assets/sounds/celebrate.mp3
ls -l assets/sounds/celebrate.mp3
ffprobe -v error -show_entries format=duration -of csv=p=0 assets/sounds/celebrate.mp3
```

Expected: a file well under 60 KB; duration about `1.3`. Listen to it once (`ffplay -autoexit -nodisp assets/sounds/celebrate.mp3`).

`app/assets/sounds/LICENSE.txt`:

```
celebrate.mp3 was generated for nemo with ffmpeg's aevalsrc filter (four
sine tones, C5 E5 G5 C6, with exponential decay; the command is in
docs/superpowers/plans/2026-09-14-achievements-celebrations.md, Task 6).

It is dedicated to the public domain under CC0 1.0:
https://creativecommons.org/publicdomain/zero/1.0/
```

In `app/pubspec.yaml`, under `flutter:` after `uses-material-design: true`:

```yaml
  assets:
    - assets/sounds/celebrate.mp3
```

- [ ] **Step 3: Write the sound player**

`app/lib/features/celebrations/data/celebration_sound.dart`:

```dart
import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Plays the sound for a big moment.
abstract interface class CelebrationSound {
  Future<void> play();
}

/// Plays the bundled chime, and never throws: a device that cannot play it
/// still gets its task ticked off.
class AssetCelebrationSound implements CelebrationSound {
  AudioPlayer? _player;

  @override
  Future<void> play() async {
    try {
      final player = _player ??= AudioPlayer();
      await player.play(AssetSource('sounds/celebrate.mp3'), volume: 0.6);
    } on Object catch (error) {
      debugPrint('Celebration sound failed: $error');
    }
  }

  Future<void> dispose() async {
    await _player?.dispose();
    _player = null;
  }
}

/// Overridden in tests: the plugin has no implementation there.
final celebrationSoundProvider = Provider<CelebrationSound>((ref) {
  final sound = AssetCelebrationSound();
  ref.onDispose(() => unawaited(sound.dispose()));
  return sound;
});
```

- [ ] **Step 4: Fake it in tests**

`app/test/support/fake_celebrations.dart`:

```dart
import 'package:nemo/features/celebrations/data/celebration_sound.dart';

/// Counts what would have played.
class RecordingCelebrationSound implements CelebrationSound {
  var plays = 0;

  @override
  Future<void> play() async => plays++;
}
```

In `app/test/support/pump_app.dart`:
- imports: `package:nemo/features/celebrations/data/celebration_sound.dart` and `'fake_celebrations.dart'`;
- parameter after `bool celebrate = false,`: `CelebrationSound? sound,`
- override, after the `photoStoreProvider` override:

```dart
      // The audio plugin has no test implementation.
      celebrationSoundProvider.overrideWithValue(
        sound ?? RecordingCelebrationSound(),
      ),
```

- [ ] **Step 5: Verify**

Run: `flutter analyze && flutter test test/features/settings/`
Expected: `No issues found!` and PASS.

- [ ] **Step 6: Commit**

```bash
git add app/pubspec.yaml pubspec.lock app/assets/sounds app/lib/features/celebrations/data app/test/support
git commit -m "feat(app): a generated chime for celebrations"
```

(The workspace lockfile is `pubspec.lock` at the repository root.)

---

### Task 7: Celebration controller and wiring the tap

**Files:**
- Create: `app/lib/features/celebrations/ui/celebration_controller.dart`, `app/lib/features/celebrations/ui/complete_task.dart`
- Modify: `app/lib/core/widgets/task_tile.dart:89-91`, `app/lib/features/tasks/ui/task_detail_screen.dart:167-169`
- Test: `app/test/features/celebrations/celebration_controller_test.dart`

**Interfaces:**
- Consumes: `AchievementsRepository`, `achievementsRepositoryProvider` (Task 3); `Achievement` (Task 2); `celebrationsEnabledProvider`, `achievementsEnabledProvider` (Task 5); `tasksRepositoryProvider`; `nowProvider`; `dayStartMsFrom`.
- Produces:
  - `sealed class CelebrationEvent`; `class TickCelebration`, `class DayClearedCelebration`, `class AchievementsUnlocked { final List<Achievement> achievements; }`
  - `class CelebrationController { CelebrationController(AchievementsRepository repo, {required DateTime Function() now, required bool Function() celebrate, required bool Function() showAchievements}); Stream<CelebrationEvent> get events; Future<void> onCompleted(Task task); Future<void> backfill(); void dispose(); }`
  - `final celebrationControllerProvider = Provider<CelebrationController>`
  - `Future<void> completeTask(WidgetRef ref, Task task, {required bool done})`

- [ ] **Step 1: Write the failing test**

`app/test/features/celebrations/celebration_controller_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/features/achievements/data/achievements_repository.dart';
import 'package:nemo/features/celebrations/ui/celebration_controller.dart';
import 'package:nemo/features/lists/data/lists_repository.dart';
import 'package:nemo/features/tasks/data/tasks_repository.dart';
import 'package:nemo/utils/dates.dart';
import 'package:nemo_core/nemo_core.dart';

import '../../support/test_db.dart';

void main() {
  late AppDatabase db;
  late TasksRepository tasks;
  late AchievementsRepository repo;
  late CelebrationController controller;
  late String inbox;
  late List<CelebrationEvent> events;
  var celebrate = true;
  var announce = true;

  setUp(() async {
    db = testDatabase();
    final clock = testClock();
    final ids = sequentialIds();
    inbox = (await ListsRepository(db, clock, ids).ensureInbox()).id;
    tasks = TasksRepository(
      db,
      clock,
      ids,
      reminders: const NoopReminderScheduler(),
      now: () => testNow,
    );
    repo = AchievementsRepository(db, now: () => testNow);
    celebrate = true;
    announce = true;
    controller = CelebrationController(
      repo,
      now: () => testNow,
      celebrate: () => celebrate,
      showAchievements: () => announce,
    );
    events = [];
    controller.events.listen(events.add);
    await controller.backfill();
  });
  tearDown(() async {
    controller.dispose();
    await db.close();
  });

  Future<Task> add(String title, {bool dueToday = false}) => tasks.create(
    listId: inbox,
    title: title,
    dueAt: dueToday ? dayStartMs(testNow) : null,
  );

  /// Ticks [task] off the way a tap does.
  Future<void> tick(Task task) async {
    await tasks.setDone(task.id, done: true);
    await controller.onCompleted(task);
    await pumpEventQueue();
  }

  List<String> unlockedIds(CelebrationEvent e) => [
    for (final a in (e as AchievementsUnlocked).achievements) a.id,
  ];

  test('the first completion unlocks the first achievement', () async {
    await tick(await add('A'));
    expect(events, hasLength(1));
    expect(unlockedIds(events.single), ['first_done']);
  });

  test('a completion that unlocks nothing is a tick', () async {
    await tick(await add('A'));
    await tick(await add('B'));
    expect(events.last, isA<TickCelebration>());
  });

  test('finishing what is due today clears the day', () async {
    await tick(await add('Someday'));
    final b = await add('B', dueToday: true);
    final c = await add('C', dueToday: true);
    await tick(b);
    expect(events.last, isA<TickCelebration>(), reason: 'C is still open');
    await tick(c);
    expect(unlockedIds(events.last), ['cleared_today']);
    await tick(await add('D', dueToday: true));
    expect(events.last, isA<DayClearedCelebration>());
    expect((await repo.stats()).clearedDays, 1, reason: 'one day, once');
  });

  test('an achievement is celebrated once', () async {
    final a = await add('A');
    await tick(a);
    await tasks.setDone(a.id, done: false);
    await tick(a);
    expect(events, hasLength(2));
    expect(events.last, isA<TickCelebration>());
  });

  test('with celebrations off only unlocks are announced', () async {
    celebrate = false;
    await tick(await add('A'));
    await tick(await add('B'));
    expect(events, hasLength(1));
    expect(events.single, isA<AchievementsUnlocked>());
  });

  test('with everything off nothing is emitted but progress is kept', () async {
    celebrate = false;
    announce = false;
    await tick(await add('A'));
    expect(events, isEmpty);
    expect(await repo.seen(), contains('first_done'));
  });

  test('what sync brought is recorded quietly, not claimed later', () async {
    for (var i = 0; i < 10; i++) {
      final t = await add('Synced $i');
      await tasks.setDone(t.id, done: true);
    }
    await controller.backfill();
    await pumpEventQueue();
    expect(events, isEmpty);
    await tick(await add('Mine'));
    expect(events.single, isA<TickCelebration>());
  });

  test('a damaged store never gets in the way of completing', () async {
    await KvStore(db).set(KvKeys.achievementsSeen, 'not json');
    await tick(await add('A'));
    expect(events.single, isA<TickCelebration>());
    expect(await repo.seen(), {'first_done'});
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/celebrations/celebration_controller_test.dart`
Expected: FAIL to compile, `celebration_controller.dart` does not exist.

- [ ] **Step 3: Write the controller**

`app/lib/features/celebrations/ui/celebration_controller.dart`:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/features/achievements/data/achievements_repository.dart';
import 'package:nemo/features/achievements/domain/achievement.dart';
import 'package:nemo/features/achievements/ui/achievements_providers.dart';
import 'package:nemo/features/settings/ui/settings_controller.dart';
import 'package:nemo/utils/dates.dart';
import 'package:nemo_core/nemo_core.dart';

/// What a completion earned; one per completion, the biggest that applies.
sealed class CelebrationEvent {
  const CelebrationEvent();
}

/// An ordinary completion.
class TickCelebration extends CelebrationEvent {
  const TickCelebration();
}

/// The last open task Today showed is done.
class DayClearedCelebration extends CelebrationEvent {
  const DayClearedCelebration();
}

class AchievementsUnlocked extends CelebrationEvent {
  const AchievementsUnlocked(this.achievements);

  final List<Achievement> achievements;
}

/// Decides what a completion made on this device earns.
///
/// Only a person's tap reaches [onCompleted]; rows written by sync never
/// do, and what they unlock is recorded quietly by [backfill] so a later
/// tap does not take the credit.
class CelebrationController {
  CelebrationController(
    this._repo, {
    required DateTime Function() now,
    required this.celebrate,
    required this.showAchievements,
  }) : _now = now;

  final AchievementsRepository _repo;
  final DateTime Function() _now;
  final bool Function() celebrate;
  final bool Function() showAchievements;
  final _events = StreamController<CelebrationEvent>.broadcast();

  Stream<CelebrationEvent> get events => _events.stream;

  /// After [task] was ticked off by a tap. Never throws: the task is
  /// already done, and a celebration going wrong must not say otherwise.
  Future<void> onCompleted(Task task) async {
    try {
      final dueAt = task.dueAt;
      final wasInToday =
          dueAt != null && dueAt < dayStartMsFrom(_now(), 1);
      final cleared = wasInToday && await _repo.todayIsClear();
      if (cleared) await _repo.recordClearedDay();

      // Unset means the quiet first check has not happened: record now,
      // celebrate nothing, rather than celebrate a whole history at once.
      final seen = await _repo.seen();
      final reached = await _reached();
      final fresh = seen == null
          ? const <Achievement>[]
          : [
              for (final a in reached)
                if (!seen.contains(a.id)) a,
            ];
      await _repo.markSeen(reached.map((a) => a.id));

      final CelebrationEvent? event;
      if (fresh.isNotEmpty && showAchievements()) {
        event = AchievementsUnlocked(fresh);
      } else if (!celebrate()) {
        event = null;
      } else if (cleared) {
        event = const DayClearedCelebration();
      } else {
        event = const TickCelebration();
      }
      if (event != null && !_events.isClosed) _events.add(event);
    } on Object catch (error, stack) {
      debugPrint('Celebration failed: $error\n$stack');
    }
  }

  /// Records everything already reached as celebrated, without a sound.
  ///
  /// Run at start and after every sync: nothing reached by then was a tap
  /// on this device, because a tap is celebrated the moment it happens.
  Future<void> backfill() async {
    try {
      await _repo.markSeen((await _reached()).map((a) => a.id));
    } on Object catch (error, stack) {
      debugPrint('Achievement backfill failed: $error\n$stack');
    }
  }

  Future<List<Achievement>> _reached() async => [
    for (final p in await _repo.progress())
      if (p.unlocked) p.achievement,
  ];

  void dispose() => unawaited(_events.close());
}

final celebrationControllerProvider = Provider<CelebrationController>((ref) {
  final controller = CelebrationController(
    ref.watch(achievementsRepositoryProvider),
    now: ref.watch(nowProvider),
    celebrate: () => ref.read(celebrationsEnabledProvider),
    showAchievements: () => ref.read(achievementsEnabledProvider),
  );
  ref.onDispose(controller.dispose);
  return controller;
});
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/celebrations/celebration_controller_test.dart`
Expected: PASS.

- [ ] **Step 5: Route taps through one helper**

`app/lib/features/celebrations/ui/complete_task.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/features/celebrations/ui/celebration_controller.dart';
import 'package:nemo/features/tasks/ui/tasks_providers.dart';
import 'package:nemo_core/nemo_core.dart';

/// Ticks [task] on or off because a person tapped it, and celebrates a
/// completion.
///
/// Both providers are read before the write: a ticked task can leave the
/// screen it was on, and a `ref` is not to be used once its widget is gone.
Future<void> completeTask(
  WidgetRef ref,
  Task task, {
  required bool done,
}) async {
  final tasks = ref.read(tasksRepositoryProvider);
  final celebrations = ref.read(celebrationControllerProvider);
  await tasks.setDone(task.id, done: done);
  if (done) await celebrations.onCompleted(task);
}
```

In `app/lib/core/widgets/task_tile.dart`, replace

```dart
              onChanged: (done) => ref
                  .read(tasksRepositoryProvider)
                  .setDone(task.id, done: done),
```

with

```dart
              onChanged: (done) => completeTask(ref, task, done: done),
```

and import `package:nemo/features/celebrations/ui/complete_task.dart`. If `tasksRepositoryProvider` is no longer used in the file, remove its import (analyze will say).

In `app/lib/features/tasks/ui/task_detail_screen.dart`, replace

```dart
                    onChanged: (done) => ref
                        .read(tasksRepositoryProvider)
                        .setDone(task.id, done: done),
```

with

```dart
                    onChanged: (done) => completeTask(ref, task, done: done),
```

and add the same import.

Then check nothing else completes tasks on a tap:

Run: `grep -rn "setDone(" lib | grep -v "features/tasks/data\|complete_task.dart"`
Expected: no output. If a line appears in UI code, route it through `completeTask` the same way.

- [ ] **Step 6: Verify**

Run: `flutter analyze && flutter test`
Expected: `No issues found!`; all tests PASS (pumpApp starts with both switches off, so existing tests see no events).

- [ ] **Step 7: Commit**

```bash
git add app/lib/features/celebrations/ui app/lib/core/widgets/task_tile.dart app/lib/features/tasks/ui/task_detail_screen.dart app/test/features/celebrations/celebration_controller_test.dart
git commit -m "feat(app): decide what completing a task earns"
```

---

### Task 8: Overlay, banner and bounce

**Files:**
- Modify: `app/pubspec.yaml`, `app/lib/app.dart:88-89`, `app/test/support/pump_app.dart`, `app/lib/core/widgets/task_tile.dart` (`DoneCheck` and its call), `app/lib/features/tasks/ui/task_detail_screen.dart` (`DoneCheck` call), the three `.arb` files
- Create: `app/lib/features/celebrations/ui/achievement_banner.dart`, `app/lib/features/celebrations/ui/celebration_overlay.dart`
- Test: `app/test/features/celebrations/celebration_overlay_test.dart`

**Interfaces:**
- Consumes: `celebrationControllerProvider`, `CelebrationEvent` subclasses (Task 7); `celebrationSoundProvider` (Task 6); `celebrationsEnabledProvider`, `celebrationSoundEnabledProvider` (Task 5); `syncEngineProvider`, `SyncStatus`; `Routes.achievements`; `RecordingCelebrationSound`.
- Produces: `class CelebrationOverlay extends ConsumerStatefulWidget { const CelebrationOverlay({required VoidCallback onOpenAchievements, required Widget child}); }`; `class AchievementBanner extends StatelessWidget` keyed `achievement-banner`; `DoneCheck({..., bool celebrate = false})`; strings `achievementUnlockedBanner`, `achievementsUnlockedMany(int count)`.

- [ ] **Step 1: Add the dependency and strings**

Run: `flutter pub add confetti:^0.8.0`
Expected: `+ confetti 0.8.0`.

`app_en.arb`:

```json
  "achievementUnlockedBanner": "Achievement unlocked",
  "achievementsUnlockedMany": "{count, plural, other{{count} achievements unlocked}}",
  "@achievementsUnlockedMany": {
    "placeholders": {"count": {"type": "int"}}
  }
```

`app_de.arb`:

```json
  "achievementUnlockedBanner": "Erfolg freigeschaltet",
  "achievementsUnlockedMany": "{count, plural, other{{count} Erfolge freigeschaltet}}"
```

`app_it.arb`:

```json
  "achievementUnlockedBanner": "Traguardo sbloccato",
  "achievementsUnlockedMany": "{count, plural, other{{count} traguardi sbloccati}}"
```

Run: `flutter gen-l10n`

- [ ] **Step 2: Write the failing test**

`app/test/features/celebrations/celebration_overlay_test.dart`:

```dart
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/core/widgets/task_tile.dart';
import 'package:nemo/features/achievements/data/achievements_repository.dart';
import 'package:nemo/features/achievements/ui/achievements_screen.dart';
import 'package:nemo/features/tasks/data/tasks_repository.dart';
import 'package:nemo/router.dart';
import 'package:nemo/utils/dates.dart';
import 'package:nemo_core/nemo_core.dart';

import '../../support/fake_celebrations.dart';
import '../../support/pump_app.dart';
import '../../support/test_db.dart';

/// Tasks due today in the inbox, and switches set before the app starts.
Future<void> Function(AppDatabase, TaskList) seedToday(
  List<String> titles, {
  Map<String, String> kv = const {},
  bool done = false,
}) => (db, inbox) async {
  for (final e in kv.entries) {
    await KvStore(db).set(e.key, e.value);
  }
  final tasks = TasksRepository(
    db,
    testClock('seed'),
    sequentialIds('task'),
    reminders: const NoopReminderScheduler(),
    now: () => testNow,
  );
  for (final title in titles) {
    final t = await tasks.create(
      listId: inbox.id,
      title: title,
      dueAt: dayStartMs(testNow),
    );
    if (done) await tasks.setDone(t.id, done: true);
  }
};

Future<void> tickOff(WidgetTester tester, String title) async {
  await tester.tap(
    find.descendant(
      of: find.widgetWithText(InkWell, title),
      matching: find.byType(DoneCheck),
    ),
  );
  // Confetti keeps frames coming, so pump a fixed while, not until settled.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

List<String> recordHaptics(WidgetTester tester) {
  final haptics = <String>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        haptics.add(call.arguments as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return haptics;
}

ConfettiControllerState confetti(WidgetTester tester) => tester
    .widget<ConfettiWidget>(find.byType(ConfettiWidget))
    .confettiController
    .state;

void main() {
  appTest('an unlock shows a banner, confetti and plays the sound', (
    tester,
  ) async {
    final sound = RecordingCelebrationSound();
    final haptics = recordHaptics(tester);
    await pumpApp(
      tester,
      celebrate: true,
      sound: sound,
      seed: seedToday(['First', 'Second'], kv: {KvKeys.celebrationSound: 'true'}),
    );

    await tickOff(tester, 'First');

    expect(find.byKey(const Key('achievement-banner')), findsOneWidget);
    expect(find.text('First step'), findsOneWidget);
    expect(confetti(tester), ConfettiControllerState.playing);
    expect(sound.plays, 1);
    expect(haptics, contains('HapticFeedbackType.mediumImpact'));

    await tester.tap(find.byKey(const Key('achievement-banner')));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(AchievementsScreen), findsOneWidget);
  });

  appTest('a plain tick is a light haptic and nothing else', (tester) async {
    final sound = RecordingCelebrationSound();
    final haptics = recordHaptics(tester);
    await pumpApp(
      tester,
      celebrate: true,
      sound: sound,
      seed: seedToday(['First', 'Second', 'Third']),
    );
    await tickOff(tester, 'First');
    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    haptics.clear();

    await tickOff(tester, 'Second');

    expect(find.byKey(const Key('achievement-banner')), findsNothing);
    expect(confetti(tester), isNot(ConfettiControllerState.playing));
    expect(haptics, ['HapticFeedbackType.lightImpact']);
    expect(sound.plays, 0, reason: 'sound is off by default');
  });

  appTest('reduced motion keeps the banner and drops the confetti', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpApp(
      tester,
      celebrate: true,
      seed: seedToday(['First', 'Second']),
    );

    await tickOff(tester, 'First');

    expect(find.byKey(const Key('achievement-banner')), findsOneWidget);
    expect(confetti(tester), isNot(ConfettiControllerState.playing));
  });

  appTest('with celebrations off an unlock is only a banner', (tester) async {
    final haptics = recordHaptics(tester);
    await pumpApp(
      tester,
      celebrate: true,
      seed: seedToday(['First', 'Second'], kv: {KvKeys.celebrations: 'false'}),
    );

    await tickOff(tester, 'First');

    expect(find.byKey(const Key('achievement-banner')), findsOneWidget);
    expect(confetti(tester), isNot(ConfettiControllerState.playing));
    expect(haptics, isEmpty);
  });

  appTest('clearing the day with achievements off is confetti, no banner', (
    tester,
  ) async {
    await pumpApp(
      tester,
      celebrate: true,
      seed: seedToday(['Only'], kv: {KvKeys.achievements: 'false'}),
    );

    await tickOff(tester, 'Only');

    expect(find.byKey(const Key('achievement-banner')), findsNothing);
    expect(confetti(tester), ConfettiControllerState.playing);
  });

  appTest('history from before is recorded without a celebration', (
    tester,
  ) async {
    final app = await pumpApp(
      tester,
      celebrate: true,
      seed: seedToday(['Old'], done: true),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('achievement-banner')), findsNothing);
    expect(
      await AchievementsRepository(app.db).seen(),
      containsAll(['first_done']),
    );
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/celebrations/celebration_overlay_test.dart`
Expected: FAIL. It compiles once `confetti` is added, but no `ConfettiWidget` or banner is found.

- [ ] **Step 4: Write the banner**

`app/lib/features/celebrations/ui/achievement_banner.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:nemo/features/achievements/domain/achievement.dart';
import 'package:nemo/l10n/app_localizations.dart';

/// Announces one or more unlocked achievements; tap to see them all.
class AchievementBanner extends StatelessWidget {
  const AchievementBanner({
    required this.achievements,
    required this.onOpen,
    required this.onClose,
    super.key,
  });

  final List<Achievement> achievements;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final single = achievements.length == 1 ? achievements.single : null;
    final headline = single?.title(l) ??
        l.achievementsUnlockedMany(achievements.length);
    return Semantics(
      liveRegion: true,
      child: Material(
        key: const Key('achievement-banner'),
        color: scheme.inverseSurface,
        elevation: 6,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
            child: Row(
              children: [
                Icon(
                  single?.icon ?? Icons.emoji_events_rounded,
                  size: 32,
                  color: scheme.inversePrimary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l.achievementUnlockedBanner,
                        style: text.labelMedium?.copyWith(
                          color: scheme.onInverseSurface.withValues(
                            alpha: 0.8,
                          ),
                        ),
                      ),
                      Text(
                        headline,
                        style: text.titleMedium?.copyWith(
                          color: scheme.onInverseSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l.commonClose,
                  onPressed: onClose,
                  icon: Icon(
                    Icons.close_rounded,
                    color: scheme.onInverseSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Write the overlay**

`app/lib/features/celebrations/ui/celebration_overlay.dart`:

```dart
import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/features/achievements/domain/achievement.dart';
import 'package:nemo/features/celebrations/data/celebration_sound.dart';
import 'package:nemo/features/celebrations/ui/achievement_banner.dart';
import 'package:nemo/features/celebrations/ui/celebration_controller.dart';
import 'package:nemo/features/settings/ui/settings_controller.dart';
import 'package:nemo/features/sync/ui/sync_engine.dart';
import 'package:nemo/features/sync/ui/sync_state.dart';

/// Shows what a completion earned, above every screen.
///
/// Sits above the router, so it is handed the way to the achievements
/// screen rather than looking the router up.
class CelebrationOverlay extends ConsumerStatefulWidget {
  const CelebrationOverlay({
    required this.onOpenAchievements,
    required this.child,
    super.key,
  });

  final VoidCallback onOpenAchievements;
  final Widget child;

  @override
  ConsumerState<CelebrationOverlay> createState() =>
      _CelebrationOverlayState();
}

class _CelebrationOverlayState extends ConsumerState<CelebrationOverlay> {
  final _confetti = ConfettiController(
    duration: const Duration(milliseconds: 600),
  );
  StreamSubscription<CelebrationEvent>? _events;
  List<Achievement>? _banner;
  Timer? _hideBanner;

  @override
  void initState() {
    super.initState();
    final controller = ref.read(celebrationControllerProvider);
    _events = controller.events.listen(_show);
    // Whatever is already reached at start was not a tap in this session.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(controller.backfill());
    });
  }

  @override
  void dispose() {
    unawaited(_events?.cancel());
    _hideBanner?.cancel();
    _confetti.dispose();
    super.dispose();
  }

  void _show(CelebrationEvent event) {
    if (!mounted) return;
    final celebrate = ref.read(celebrationsEnabledProvider);
    final big = event is! TickCelebration;
    if (celebrate) {
      unawaited(
        big ? HapticFeedback.mediumImpact() : HapticFeedback.lightImpact(),
      );
    }
    if (!big) return;
    if (celebrate && !MediaQuery.disableAnimationsOf(context)) {
      _confetti.play();
    }
    if (celebrate && ref.read(celebrationSoundEnabledProvider)) {
      unawaited(ref.read(celebrationSoundProvider).play());
    }
    if (event is AchievementsUnlocked) {
      setState(() => _banner = event.achievements);
      _hideBanner?.cancel();
      _hideBanner = Timer(const Duration(seconds: 4), _closeBanner);
    }
  }

  void _closeBanner() {
    _hideBanner?.cancel();
    if (mounted) setState(() => _banner = null);
  }

  @override
  Widget build(BuildContext context) {
    // Rows a sync brought in are recorded quietly once it finishes, so the
    // next tap here does not celebrate another device's progress.
    ref.listen(syncEngineProvider, (previous, next) {
      if (previous?.status == SyncStatus.syncing &&
          next.status != SyncStatus.syncing) {
        unawaited(ref.read(celebrationControllerProvider).backfill());
      }
    });
    final scheme = Theme.of(context).colorScheme;
    final banner = _banner;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Align(
          alignment: Alignment.topCenter,
          child: IgnorePointer(
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 24,
              emissionFrequency: 0.05,
              minBlastForce: 10,
              maxBlastForce: 30,
              gravity: 0.25,
              colors: [
                scheme.primary,
                scheme.secondary,
                scheme.tertiary,
                scheme.primaryContainer,
                scheme.tertiaryContainer,
              ],
            ),
          ),
        ),
        if (banner != null)
          Positioned(
            left: 16,
            right: 16,
            top: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: AchievementBanner(
                      achievements: banner,
                      onClose: _closeBanner,
                      onOpen: () {
                        _closeBanner();
                        widget.onOpenAchievements();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 6: Put the overlay in both apps**

In `app/lib/app.dart`, import the overlay and `dart:async` is already imported; replace

```dart
      builder: (context, child) =>
          SyncLifecycleObserver(child: child ?? const SizedBox.shrink()),
```

with

```dart
      builder: (context, child) => SyncLifecycleObserver(
        child: CelebrationOverlay(
          onOpenAchievements: () =>
              unawaited(_router.push(Routes.achievements)),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
```

In `app/test/support/pump_app.dart`, import `package:nemo/features/celebrations/ui/celebration_overlay.dart` and `dart:async`; add to the `MaterialApp.router(...)` after `routerConfig: router,`:

```dart
          builder: (context, child) => CelebrationOverlay(
            onOpenAchievements: () =>
                unawaited(router.push(Routes.achievements)),
            child: child ?? const SizedBox.shrink(),
          ),
```

- [ ] **Step 7: Give DoneCheck its bounce**

In `app/lib/core/widgets/task_tile.dart`, replace the whole `DoneCheck` class (from `/// Round animated checkbox; the ring takes the priority colour.` to the end of that class) with:

```dart
/// Round animated checkbox; the ring takes the priority colour.
///
/// With [celebrate], ticking it on bounces and sends a ring outwards,
/// unless the platform asks for reduced motion.
class DoneCheck extends StatefulWidget {
  const DoneCheck({
    required this.done,
    required this.onChanged,
    this.color,
    this.celebrate = false,
    super.key,
  });

  final bool done;
  final Color? color;
  final ValueChanged<bool> onChanged;
  final bool celebrate;

  @override
  State<DoneCheck> createState() => _DoneCheckState();
}

class _DoneCheckState extends State<DoneCheck>
    with SingleTickerProviderStateMixin {
  late final _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  late final _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1,
        end: 1.25,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 40,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1.25,
        end: 1,
      ).chain(CurveTween(curve: Curves.easeIn)),
      weight: 60,
    ),
  ]).animate(_bounce);

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  void _toggle() {
    if (!widget.done &&
        widget.celebrate &&
        !MediaQuery.disableAnimationsOf(context)) {
      unawaited(_bounce.forward(from: 0));
    }
    widget.onChanged(!widget.done);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ring = widget.color ?? scheme.outline;
    final done = widget.done;
    return Semantics(
      checked: done,
      button: true,
      child: InkResponse(
        onTap: _toggle,
        radius: 22,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              AnimatedBuilder(
                animation: _bounce,
                builder: (context, _) {
                  final t = _bounce.value;
                  if (t == 0 || t == 1) {
                    return const SizedBox(width: 24, height: 24);
                  }
                  return Transform.scale(
                    scale: 1 + t,
                    child: Opacity(
                      opacity: 1 - t,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: scheme.primary, width: 2),
                        ),
                      ),
                    ),
                  );
                },
              ),
              ScaleTransition(
                scale: _scale,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? scheme.primary : Colors.transparent,
                    border: Border.all(
                      color: done ? scheme.primary : ring,
                      width: 2,
                    ),
                  ),
                  child: done
                      ? Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: scheme.onPrimary,
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

Add `import 'dart:async';` at the top of `task_tile.dart` if absent. In the same file's `TaskTile.build`, and in `task_detail_screen.dart`, add to each `DoneCheck(...)` call:

```dart
              celebrate: ref.watch(celebrationsEnabledProvider),
```

importing `package:nemo/features/settings/ui/settings_controller.dart` in both files.

- [ ] **Step 8: Run tests to verify they pass**

Run: `flutter test test/features/celebrations/ test/l10n/translations_test.dart`
Expected: PASS.

Run: `flutter analyze && flutter test`
Expected: `No issues found!`; everything PASS.

- [ ] **Step 9: Commit**

```bash
git add app/pubspec.yaml pubspec.lock app/lib app/test
git commit -m "feat(app): confetti, a banner and a bounce for completed tasks"
```

(The workspace lockfile is `pubspec.lock` at the repository root.)

---

### Task 9: Screenshot, docs and a real run

**Files:**
- Modify: `app/test/design/screens_test.dart`, `README.md`, `CHANGELOG.md`, `docs/superpowers/specs/2026-09-14-achievements-celebrations-design.md`

- [ ] **Step 1: Add the screenshot**

In `app/test/design/screens_test.dart`, after the `settings` test:

```dart
  appTest(
    'achievements',
    (t) => shoot(t, 'achievements', location: Routes.achievements),
  );
```

Run: `flutter test test/design --update-goldens`
Expected: PASS; open `app/build/screens/achievements.png` and check that the cards neither overflow nor clip their text.

- [ ] **Step 2: README**

In `README.md`, after the bullet that starts `- Tasks that repeat`, add:

```markdown
- Ticking a task off feels like it: a small bounce on every tick, confetti
  when Today is cleared, and ten achievements to unlock, from the first
  task done to a 30-day streak. Settings turns celebrations, their sound
  and achievements off one by one, for a quieter, more professional app.
```

- [ ] **Step 3: CHANGELOG**

In `CHANGELOG.md`, directly above `## 0.7.0 - 2026-09-14`:

```markdown
## Unreleased

### Added

- Completing a task is celebrated: the check bounces, clearing Today sets
  off confetti, and ten achievements -- from the first task done to a
  30-day streak -- announce themselves as they are unlocked and are listed
  under Settings. An optional sound plays for the big moments.
- Settings has switches for celebrations, their sound and achievements, so
  the app can be kept quiet. They apply to this device only.

```

- [ ] **Step 4: Record where the build differs from the spec**

In the spec:
- In the Decisions table, replace the Sound row's value with `A short generated chime, behind its own switch, off by default`.
- In "Controller", replace step 1 (`If Celebrations is off and Achievements is off, stop.`) with: `1. Bookkeeping always runs, whatever the switches say, so turning a switch back on never replays old progress; only the event emitted in step 4 depends on them.`
- In "Backfill", replace the first paragraph's opening `On the first start of a version with this feature (`kv` key `achievements_seen` absent), every achievement` with `On every start, every achievement`.
- In "Sound", replace the asset sentence with: `The real implementation uses audioplayers with one bundled asset, app/assets/sounds/celebrate.mp3: a 1.3 s four-note chime generated with ffmpeg and dedicated to the public domain (CC0), recorded in app/assets/sounds/LICENSE.txt. MP3 plays on Android and in every supported browser, so no second format ships.`
- In "Presentation", replace `using the theme's primary, tertiary and priority colours` with `using colours from the theme's colour scheme`.

- [ ] **Step 5: Full verification**

Run from the repository root, in order:

```bash
(cd app && flutter gen-l10n && dart run build_runner build)
git status --short   # generated files must show no unexpected changes
(cd app && flutter analyze)
(cd app && flutter test --exclude-tags design)
```

Expected: no generated-file drift, `No issues found!`, all tests PASS.

- [ ] **Step 6: See it in the real app**

Run the web build locally (`cd app && flutter run -d chrome`) and check by hand:
1. Tick a task on Today: the check bounces; the "First step" banner appears with confetti; tapping it opens Achievements.
2. Turn Sound on in Settings; clear Today: confetti and the chime.
3. Turn Celebrations off: ticks are plain; turn Achievements off: the tile disappears and no banner shows.
4. In the browser's rendering settings, emulate `prefers-reduced-motion`: no confetti or bounce, the banner still appears.

- [ ] **Step 7: Commit**

```bash
git add app/test/design/screens_test.dart README.md CHANGELOG.md docs/superpowers/specs/2026-09-14-achievements-celebrations-design.md
git commit -m "docs: describe celebrations and achievements"
```
