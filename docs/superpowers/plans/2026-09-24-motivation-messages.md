# Motivation Messages Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every tap-completion a short, varied, calm message in a floating pill (or in the swipe's Undo snackbar), and show Today's progress with an encouraging line and a welcome-back after a break.

**Architecture:** A pure `pickMotivation` chooses a message id from a small context. `CelebrationController` gathers that context after the tap's write and attaches the choice to the event it already emits. `CelebrationOverlay` shows the pill; the swipe path puts the text in its snackbar. A `TodayProgress` widget on the Today screen shows a bar, a count and a line. Spec: `docs/superpowers/specs/2026-09-24-motivation-messages-design.md`.

**Tech Stack:** Flutter 3.47 (fvm), Riverpod, drift, flutter_test with the `pumpApp` harness.

## Global Constraints

- UI and local queries only: no change to `nemo_core` models, the database schema, sync or the server.
- Messages, the pill and the Today header's line follow the existing Celebrations switch (`celebrationsEnabledProvider`). Off: no pill, the swipe snackbar says `tasksCompletedSnack`, the header shows only bar and count.
- The progress bar and count show whenever Today has tasks, regardless of the switch.
- Only a tap-completion on this device gets a message: never on untick, never for sync.
- An achievement unlock keeps its banner and shows no pill.
- Tone: warm and calm, no emoji, never guilt. Message texts are exactly those in the spec (English); de/it as given in Task 2.
- A message among the last five shown is not picked again while another variant of that kind is available.
- Pill: bottom-centred above the navigation bar, ~2.5 s hold, 150 ms fade in / 200 ms fade out, `IgnorePointer`, `Semantics(liveRegion: true)`, no fade under reduced motion, replaced immediately by a newer message, key `motivation-pill`.
- New l10n keys in `app_en.arb`, `app_de.arb`, `app_it.arb`; regenerate with `flutter gen-l10n` from `app/`.
- Toolchain: `export PATH=~/fvm/versions/3.47.2/bin:$PATH`, run from `app/`; `flutter test --concurrency=2` on a directory or single file, one process at a time, 600 s timeout.
- Commit messages end with the attribution lines in the session's system reminder.
- Branch `feat/motivation-messages` (checked out, spec committed).

## File Structure

| File | Responsibility |
|---|---|
| `lib/features/celebrations/domain/motivation.dart` (create) | `MotivationKind`, `MotivationContext`, `Motivation`, `motivationVariants`, `pickMotivation` |
| `lib/features/celebrations/ui/motivation_text.dart` (create) | `motivationText(L, Motivation, MotivationContext)`, `todayLine(L, ...)` |
| `lib/features/achievements/domain/completion_stats.dart` (modify) | `lastDoneAt` |
| `lib/features/achievements/data/achievements_repository.dart` (modify) | `todayCounts()`, `doneTodayCount()` |
| `lib/features/celebrations/ui/celebration_controller.dart` (modify) | context gathering, motivation on events, `showPill` |
| `lib/features/celebrations/ui/complete_task.dart` (modify) | `showPill`, return the motivation |
| `lib/features/celebrations/ui/motivation_pill.dart` (create) | the pill widget |
| `lib/features/celebrations/ui/celebration_overlay.dart` (modify) | show / replace / hide the pill |
| `lib/features/tasks/ui/task_list_view.dart` (modify) | swipe snackbar text |
| `lib/features/tasks/ui/today_progress.dart` (create) | Today bar, count, line |
| `lib/features/tasks/ui/today_screen.dart` (modify) | place `TodayProgress` |
| `lib/l10n/app_{en,de,it}.arb` | strings |
| `CHANGELOG.md` | `## Unreleased` |

---

### Task 1: Pure message chooser

**Files:**
- Create: `app/lib/features/celebrations/domain/motivation.dart`
- Test: `app/test/features/celebrations/motivation_test.dart`

**Interfaces:**
- Produces: `enum MotivationKind { dayCleared, lastOne, halfway, streakDay, firstOfDay, overdue, progress, generic }`; `class MotivationContext` (fields below); `class Motivation { final MotivationKind kind; final int variant; }` with value equality; `const Map<MotivationKind, int> motivationVariants`; `Motivation pickMotivation(MotivationContext c, {required List<Motivation> recent, required Random random})`.

- [ ] **Step 1: Write the failing tests**

```dart
// app/test/features/celebrations/motivation_test.dart
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/celebrations/domain/motivation.dart';

MotivationContext ctx({
  int done = 1,
  int total = 5,
  bool inToday = true,
  bool first = false,
  int streak = 1,
  bool overdue = false,
  bool cleared = false,
}) => MotivationContext(
  todayDone: done,
  todayTotal: total,
  wasInToday: inToday,
  firstToday: first,
  streak: streak,
  wasOverdue: overdue,
  cleared: cleared,
);

MotivationKind kindOf(MotivationContext c, {int seed = 1}) =>
    pickMotivation(c, recent: const [], random: Random(seed)).kind;

void main() {
  test('priority: cleared beats everything', () {
    expect(
      kindOf(ctx(done: 5, total: 5, first: true, streak: 3, overdue: true, cleared: true)),
      MotivationKind.dayCleared,
    );
  });

  test('one left', () {
    expect(kindOf(ctx(done: 4, total: 5)), MotivationKind.lastOne);
    expect(kindOf(ctx(done: 1, total: 2, first: true)), MotivationKind.lastOne);
  });

  test('halfway only on the tick that crosses it, and not on small days', () {
    expect(kindOf(ctx(done: 2, total: 4)), MotivationKind.halfway);
    expect(kindOf(ctx(done: 3, total: 6)), MotivationKind.halfway);
    expect(kindOf(ctx(done: 3, total: 5)), MotivationKind.halfway);
    expect(kindOf(ctx(done: 4, total: 6)), isNot(MotivationKind.halfway));
    expect(kindOf(ctx(done: 2, total: 3)), MotivationKind.lastOne);
  });

  test('first of the day, with and without a streak', () {
    expect(kindOf(ctx(done: 1, total: 6, first: true, streak: 4)),
        MotivationKind.streakDay);
    expect(kindOf(ctx(done: 1, total: 6, first: true, streak: 1)),
        MotivationKind.firstOfDay);
    expect(
      kindOf(ctx(done: 0, total: 0, inToday: false, first: true, streak: 1)),
      MotivationKind.firstOfDay,
    );
  });

  test('an overdue task gets its own line', () {
    expect(kindOf(ctx(done: 1, total: 8, overdue: true)), MotivationKind.overdue);
  });

  test('ordinary ticks mix progress and generic, generic outside Today', () {
    final kinds = {
      for (var s = 0; s < 60; s++) kindOf(ctx(done: 1, total: 8), seed: s),
    };
    expect(kinds, {MotivationKind.progress, MotivationKind.generic});
    for (var s = 0; s < 20; s++) {
      expect(
        kindOf(ctx(done: 0, total: 0, inToday: false), seed: s),
        MotivationKind.generic,
      );
    }
  });

  test('a variant among the last five is not repeated', () {
    final c = ctx(done: 1, total: 0, inToday: false);
    final recent = <Motivation>[];
    for (var i = 0; i < 40; i++) {
      final m = pickMotivation(c, recent: recent, random: Random(i));
      expect(recent.skip(recent.length > 5 ? recent.length - 5 : 0), isNot(contains(m)));
      recent.add(m);
    }
  });

  test('when every variant is recent, one is still picked', () {
    final c = ctx(done: 4, total: 5); // lastOne has 3 variants
    final recent = [
      for (var v = 0; v < motivationVariants[MotivationKind.lastOne]!; v++)
        Motivation(MotivationKind.lastOne, v),
    ];
    final m = pickMotivation(c, recent: recent, random: Random(3));
    expect(m.kind, MotivationKind.lastOne);
    expect(m.variant, lessThan(motivationVariants[MotivationKind.lastOne]!));
  });

  test('every kind has variants', () {
    for (final k in MotivationKind.values) {
      expect(motivationVariants[k], greaterThan(0), reason: '$k');
    }
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/celebrations/motivation_test.dart`
Expected: compile error, `motivation.dart` not found.

- [ ] **Step 3: Implement**

```dart
// app/lib/features/celebrations/domain/motivation.dart

/// Choosing what to say when a task is ticked off.
///
/// Pure, so every rule is a unit test; the celebration controller gathers
/// the context and the overlay turns the choice into words.
library;

import 'dart:math';

import 'package:meta/meta.dart';

enum MotivationKind {
  /// Today just became empty.
  dayCleared,

  /// Exactly one Today task is left open.
  lastOne,

  /// This tick crossed half of Today.
  halfway,

  /// First completion today, continuing a streak of two days or more.
  streakDay,

  /// First completion today, no streak.
  firstOfDay,

  /// The task was due before today.
  overdue,

  /// "{done} of {total} done today".
  progress,

  /// Anything else.
  generic,
}

/// How many variants each kind has. The strings in `motivation_text.dart`
/// must provide exactly these.
const Map<MotivationKind, int> motivationVariants = {
  MotivationKind.dayCleared: 4,
  MotivationKind.lastOne: 3,
  MotivationKind.halfway: 3,
  MotivationKind.streakDay: 3,
  MotivationKind.firstOfDay: 4,
  MotivationKind.overdue: 3,
  MotivationKind.progress: 2,
  MotivationKind.generic: 12,
};

/// What is known about a completion when its message is chosen. Counts
/// already include the task just ticked off.
@immutable
class MotivationContext {
  const MotivationContext({
    required this.todayDone,
    required this.todayTotal,
    required this.wasInToday,
    required this.firstToday,
    required this.streak,
    required this.wasOverdue,
    required this.cleared,
  });

  /// Today tasks completed today.
  final int todayDone;

  /// [todayDone] plus Today tasks still open.
  final int todayTotal;

  /// The ticked task was one Today showed.
  final bool wasInToday;

  /// No other task was completed earlier today.
  final bool firstToday;

  /// Consecutive days with a completion, including today.
  final int streak;

  /// The task was due before the start of today.
  final bool wasOverdue;

  /// Nothing Today shows is open any more.
  final bool cleared;

  int get todayLeft => todayTotal - todayDone;
}

@immutable
class Motivation {
  const Motivation(this.kind, this.variant);

  final MotivationKind kind;

  /// Index into that kind's variants.
  final int variant;

  @override
  bool operator ==(Object other) =>
      other is Motivation && other.kind == kind && other.variant == variant;

  @override
  int get hashCode => Object.hash(kind, variant);

  @override
  String toString() => 'Motivation($kind, $variant)';
}

/// How many recent messages a new one must differ from.
const motivationMemory = 5;

/// Picks the message for a completion; the most specific situation wins.
///
/// [recent] holds the messages shown so far, newest last; a variant among
/// the last [motivationMemory] is skipped while another is left. [random]
/// is injected so tests are deterministic.
Motivation pickMotivation(
  MotivationContext c, {
  required List<Motivation> recent,
  required Random random,
}) {
  final kind = _kindFor(c, random);
  final count = motivationVariants[kind]!;
  final lately = recent.length > motivationMemory
      ? recent.sublist(recent.length - motivationMemory)
      : recent;
  final fresh = [
    for (var v = 0; v < count; v++)
      if (!lately.contains(Motivation(kind, v))) v,
  ];
  final pool = fresh.isEmpty ? [for (var v = 0; v < count; v++) v] : fresh;
  return Motivation(kind, pool[random.nextInt(pool.length)]);
}

MotivationKind _kindFor(MotivationContext c, Random random) {
  if (c.cleared) return MotivationKind.dayCleared;
  if (c.wasInToday && c.todayLeft == 1) return MotivationKind.lastOne;
  // Crossed by this tick; a day of two or three tasks goes straight from
  // the first to "one to go", which says the same thing better.
  if (c.wasInToday &&
      c.todayTotal >= 4 &&
      c.todayDone * 2 >= c.todayTotal &&
      (c.todayDone - 1) * 2 < c.todayTotal) {
    return MotivationKind.halfway;
  }
  if (c.firstToday) {
    return c.streak >= 2 ? MotivationKind.streakDay : MotivationKind.firstOfDay;
  }
  if (c.wasOverdue) return MotivationKind.overdue;
  // A count now and then says how the day is going without every line
  // being a number.
  if (c.wasInToday && c.todayTotal >= 2 && random.nextInt(3) == 0) {
    return MotivationKind.progress;
  }
  return MotivationKind.generic;
}
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/celebrations/motivation_test.dart` -- all pass. `dart format lib test && flutter analyze` clean.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/celebrations/domain/motivation.dart app/test/features/celebrations/motivation_test.dart
git commit -m "feat(app): choose a varied message for a completed task"
```

---

### Task 2: Message strings

**Files:**
- Modify: `app/lib/l10n/app_en.arb`, `app_de.arb`, `app_it.arb` (+ `flutter gen-l10n`)
- Create: `app/lib/features/celebrations/ui/motivation_text.dart`
- Test: `app/test/features/celebrations/motivation_text_test.dart`

**Interfaces:**
- Consumes: `Motivation`, `MotivationKind`, `MotivationContext`, `motivationVariants` (Task 1).
- Produces: `String motivationText(L l, Motivation m, MotivationContext c)`; `enum TodayLine { welcomeBack, freshStart, allClear }` and `String todayLineText(L l, TodayLine line, int dayOfYear)`; l10n keys listed below plus `todayProgressCount` ("{done} of {total} done").

- [ ] **Step 1: Add the strings**

Keys are `motivation<Kind><n>` with `n` from 0. Add each key to all three arb files; in `app_en.arb` give every key an `@` description ("Message after ticking off a task: <situation>.") and, for keys with placeholders, `"placeholders": {"days": {"type": "int"}}` or `done`/`total`/`left` as `int`.

| key | en | de | it |
|---|---|---|---|
| motivationDayCleared0 | All clear for today. Enjoy it. | Alles erledigt für heute. Genieß es. | Tutto fatto per oggi. Goditela. |
| motivationDayCleared1 | That's everything for today. Well done. | Das war alles für heute. Gut gemacht. | È tutto per oggi. Ben fatto. |
| motivationDayCleared2 | Today's list is empty. Nice work. | Die Liste für heute ist leer. Schön. | La lista di oggi è vuota. Ottimo lavoro. |
| motivationDayCleared3 | All done. Time for something you enjoy. | Fertig. Zeit für etwas Schönes. | Finito. Tempo per qualcosa che ti piace. |
| motivationLastOne0 | One to go. | Noch eins. | Ne manca una. |
| motivationLastOne1 | Just one left. | Nur noch eins übrig. | Ne resta solo una. |
| motivationLastOne2 | Nearly there. One more. | Fast geschafft. Noch eins. | Ci sei quasi. Ancora una. |
| motivationHalfway0 | Halfway there. | Die Hälfte ist geschafft. | Sei a metà. |
| motivationHalfway1 | Half of today, done. | Der halbe Tag ist erledigt. | Metà della giornata, fatta. |
| motivationHalfway2 | Good pace. Halfway through. | Gutes Tempo. Halbzeit. | Buon ritmo. Sei a metà. |
| motivationStreakDay0 | Day {days} in a row. | Tag {days} in Folge. | {days} giorni di fila. |
| motivationStreakDay1 | {days} days running. Keep it gentle. | {days} Tage am Stück. Ganz entspannt. | {days} giorni di fila. Con calma. |
| motivationStreakDay2 | Another day, another step. {days} in a row. | Ein Tag, ein Schritt. {days} in Folge. | Un altro giorno, un altro passo. {days} di fila. |
| motivationFirstOfDay0 | Good start. | Guter Anfang. | Buon inizio. |
| motivationFirstOfDay1 | First one done. The rest is easier. | Das Erste ist erledigt. Der Rest geht leichter. | La prima è fatta. Il resto è più facile. |
| motivationFirstOfDay2 | And the day is moving. | Und der Tag kommt in Schwung. | E la giornata si mette in moto. |
| motivationFirstOfDay3 | Off to a good start. | Ein guter Start. | Si parte bene. |
| motivationOverdue0 | That one's been waiting. Good to have it gone. | Das hat gewartet. Gut, dass es erledigt ist. | Aspettava da un po'. Bene che sia fatta. |
| motivationOverdue1 | Off your mind at last. | Endlich aus dem Kopf. | Finalmente fuori dai pensieri. |
| motivationOverdue2 | Finally done. That feels better. | Endlich erledigt. Das fühlt sich besser an. | Finalmente fatta. Va meglio così. |
| motivationProgress0 | {done} of {total} done today. | {done} von {total} heute erledigt. | {done} su {total} fatte oggi. |
| motivationProgress1 | {done} down, {left} to go. | {done} erledigt, {left} noch offen. | {done} fatte, ne mancano {left}. |
| motivationGeneric0 | Nice, one less thing. | Schön, eins weniger. | Bene, una cosa in meno. |
| motivationGeneric1 | Done and dusted. | Erledigt und abgehakt. | Fatto e finito. |
| motivationGeneric2 | Progress feels good. | Fortschritt fühlt sich gut an. | Fare progressi fa bene. |
| motivationGeneric3 | Another one done. | Wieder eins erledigt. | Un'altra fatta. |
| motivationGeneric4 | Ticked off. | Abgehakt. | Spuntata. |
| motivationGeneric5 | That's handled. | Das ist erledigt. | Sistemata. |
| motivationGeneric6 | Good work. | Gute Arbeit. | Buon lavoro. |
| motivationGeneric7 | One step further. | Einen Schritt weiter. | Un passo avanti. |
| motivationGeneric8 | Nicely done. | Schön gemacht. | Fatto bene. |
| motivationGeneric9 | Crossed off. | Durchgestrichen. | Cancellata dalla lista. |
| motivationGeneric10 | Keep going, gently. | Weiter so, ganz in Ruhe. | Avanti così, con calma. |
| motivationGeneric11 | Small steps count. | Kleine Schritte zählen. | Anche i piccoli passi contano. |
| todayProgressCount | {done} of {total} done | {done} von {total} erledigt | {done} su {total} fatte |
| todayWelcomeBack0 | Welcome back. One small thing is a good start. | Schön, dass du wieder da bist. Eine Kleinigkeit ist ein guter Anfang. | Bentornato. Una piccola cosa è un buon inizio. |
| todayWelcomeBack1 | Good to see you. Start with something easy. | Schön, dich zu sehen. Fang mit etwas Leichtem an. | Che bello rivederti. Inizia da qualcosa di facile. |
| todayFreshStart0 | A fresh start. | Ein frischer Anfang. | Un nuovo inizio. |
| todayFreshStart1 | Pick one to begin. | Such dir eins zum Anfangen aus. | Scegline una per iniziare. |
| todayFreshStart2 | One thing at a time. | Eins nach dem anderen. | Una cosa alla volta. |
| todayAllClear | All clear. Enjoy the rest of your day. | Alles erledigt. Genieß den Rest des Tages. | Tutto fatto. Goditi il resto della giornata. |

Run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing test**

```dart
// app/test/features/celebrations/motivation_text_test.dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/celebrations/domain/motivation.dart';
import 'package:nemo/features/celebrations/ui/motivation_text.dart';
import 'package:nemo/l10n/app_localizations.dart';

const _c = MotivationContext(
  todayDone: 3,
  todayTotal: 5,
  wasInToday: true,
  firstToday: false,
  streak: 4,
  wasOverdue: false,
  cleared: false,
);

void main() {
  for (final locale in L.supportedLocales) {
    test('every variant has text in $locale', () async {
      final l = await L.delegate.load(locale);
      for (final kind in MotivationKind.values) {
        for (var v = 0; v < motivationVariants[kind]!; v++) {
          final text = motivationText(l, Motivation(kind, v), _c);
          expect(text.trim(), isNotEmpty, reason: '$kind $v');
          expect(text, isNot(contains('{')), reason: '$kind $v');
        }
      }
      for (final line in TodayLine.values) {
        for (var day = 0; day < 4; day++) {
          expect(todayLineText(l, line, day).trim(), isNotEmpty);
        }
      }
    });
  }

  test('placeholders are filled in English', () async {
    final l = await L.delegate.load(const Locale('en'));
    expect(
      motivationText(l, const Motivation(MotivationKind.progress, 0), _c),
      '3 of 5 done today.',
    );
    expect(
      motivationText(l, const Motivation(MotivationKind.progress, 1), _c),
      '3 down, 2 to go.',
    );
    expect(
      motivationText(l, const Motivation(MotivationKind.streakDay, 0), _c),
      'Day 4 in a row.',
    );
  });

  test('an out-of-range variant falls back to the first', () async {
    final l = await L.delegate.load(const Locale('en'));
    expect(
      motivationText(l, const Motivation(MotivationKind.lastOne, 99), _c),
      'One to go.',
    );
  });
}
```

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/features/celebrations/motivation_text_test.dart` -- `motivation_text.dart` not found.

- [ ] **Step 4: Implement**

```dart
// app/lib/features/celebrations/ui/motivation_text.dart
import 'package:nemo/features/celebrations/domain/motivation.dart';
import 'package:nemo/l10n/app_localizations.dart';

/// The words for [m]. An index past the kind's variants -- which the
/// chooser never produces -- falls back to the first.
String motivationText(L l, Motivation m, MotivationContext c) {
  final variants = switch (m.kind) {
    MotivationKind.dayCleared => [
      l.motivationDayCleared0,
      l.motivationDayCleared1,
      l.motivationDayCleared2,
      l.motivationDayCleared3,
    ],
    MotivationKind.lastOne => [
      l.motivationLastOne0,
      l.motivationLastOne1,
      l.motivationLastOne2,
    ],
    MotivationKind.halfway => [
      l.motivationHalfway0,
      l.motivationHalfway1,
      l.motivationHalfway2,
    ],
    MotivationKind.streakDay => [
      l.motivationStreakDay0(c.streak),
      l.motivationStreakDay1(c.streak),
      l.motivationStreakDay2(c.streak),
    ],
    MotivationKind.firstOfDay => [
      l.motivationFirstOfDay0,
      l.motivationFirstOfDay1,
      l.motivationFirstOfDay2,
      l.motivationFirstOfDay3,
    ],
    MotivationKind.overdue => [
      l.motivationOverdue0,
      l.motivationOverdue1,
      l.motivationOverdue2,
    ],
    MotivationKind.progress => [
      l.motivationProgress0(c.todayDone, c.todayTotal),
      l.motivationProgress1(c.todayDone, c.todayLeft),
    ],
    MotivationKind.generic => [
      l.motivationGeneric0,
      l.motivationGeneric1,
      l.motivationGeneric2,
      l.motivationGeneric3,
      l.motivationGeneric4,
      l.motivationGeneric5,
      l.motivationGeneric6,
      l.motivationGeneric7,
      l.motivationGeneric8,
      l.motivationGeneric9,
      l.motivationGeneric10,
      l.motivationGeneric11,
    ],
  };
  return m.variant >= 0 && m.variant < variants.length
      ? variants[m.variant]
      : variants.first;
}

/// The Today header's line, when it has one.
enum TodayLine { welcomeBack, freshStart, allClear }

/// [line]'s words, the variant chosen by [dayOfYear] so it stays the same
/// all day rather than changing on every rebuild.
String todayLineText(L l, TodayLine line, int dayOfYear) {
  final variants = switch (line) {
    TodayLine.welcomeBack => [l.todayWelcomeBack0, l.todayWelcomeBack1],
    TodayLine.freshStart => [
      l.todayFreshStart0,
      l.todayFreshStart1,
      l.todayFreshStart2,
    ],
    TodayLine.allClear => [l.todayAllClear],
  };
  return variants[dayOfYear % variants.length];
}
```

Argument order for generated methods with several placeholders follows the order the placeholders appear in the `@key.placeholders` map; declare `done` before `total`/`left` in `app_en.arb`.

- [ ] **Step 5: Run to verify pass**

Run: `flutter test test/features/celebrations/motivation_text_test.dart` -- pass. Format and analyze clean.

- [ ] **Step 6: Commit**

```bash
git add app/lib/l10n app/lib/features/celebrations/ui/motivation_text.dart app/test/features/celebrations/motivation_text_test.dart
git commit -m "feat(app): write the completion messages in English, German and Italian"
```

---

### Task 3: Stats and Today counts

**Files:**
- Modify: `app/lib/features/achievements/domain/completion_stats.dart`
- Modify: `app/lib/features/achievements/data/achievements_repository.dart`
- Test: `app/test/features/achievements/completion_stats_test.dart`, `app/test/features/achievements/achievements_repository_test.dart`

**Interfaces:**
- Produces: `CompletionStats.lastDoneAt` (`int?`, epoch ms of the latest `doneAt` among done, undeleted tasks); `Future<({int done, int open})> AchievementsRepository.todayCounts()`; `Future<int> AchievementsRepository.doneTodayCount()`.

Definitions (match `TasksRepository.watchToday` and `todayIsClear`):
- `todayCounts().open`: undeleted tasks in undeleted lists, `done == false`, `dueAt != null`, `dueAt < start of tomorrow`.
- `todayCounts().done`: undeleted tasks in undeleted lists, `done == true`, `dueAt != null`, `dueAt < start of tomorrow`, `doneAt >= start of today`.
- `doneTodayCount()`: undeleted tasks in undeleted lists, `done == true`, `doneAt >= start of today` (any due date or none).

- [ ] **Step 1: Write the failing tests**

In `completion_stats_test.dart`, add:

```dart
  test('lastDoneAt is the latest completion, null when none', () {
    final now = DateTime(2026, 9, 24, 12);
    expect(
      CompletionStats.from(tasks: const [], subtasks: const [], now: now)
          .lastDoneAt,
      isNull,
    );
    Task done(String id, int doneAt) => Task(
      id: id,
      listId: 'l',
      title: id,
      sortKey: 'a',
      updatedAt: 'u',
      done: true,
      doneAt: doneAt,
    );
    final stats = CompletionStats.from(
      tasks: [done('a', 100), done('b', 300), done('c', 200)],
      subtasks: const [],
      now: now,
    );
    expect(stats.lastDoneAt, 300);
  });
```

(Adapt the `Task` constructor to the helper the file already uses for tasks if there is one.)

In `achievements_repository_test.dart`, following the file's existing setup (a `TasksRepository`, an inbox, `testNow`), add:

```dart
  test('todayCounts and doneTodayCount follow Today', () async {
    final a = await tasks.create(listId: inbox, title: 'A', dueAt: dayStartMs(testNow));
    await tasks.create(listId: inbox, title: 'B', dueAt: dayStartMs(testNow));
    final c = await tasks.create(listId: inbox, title: 'C'); // no due date
    await tasks.create(
      listId: inbox,
      title: 'Later',
      dueAt: dayStartMsFrom(testNow, 3),
    );
    await tasks.setDone(a.id, done: true);
    await tasks.setDone(c.id, done: true);

    expect(await repo.todayCounts(), (done: 1, open: 1));
    expect(await repo.doneTodayCount(), 2);
  });
```

(Use the file's own names for the tasks repository, inbox id and `repo`; if it lacks a `TasksRepository`, build one as `celebration_controller_test.dart` does.)

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/achievements` -- the new tests fail (`lastDoneAt`, `todayCounts` undefined).

- [ ] **Step 3: Implement**

`completion_stats.dart`: add `this.lastDoneAt` to the const constructor, a field

```dart
  /// When the latest completion happened, in epoch milliseconds; null
  /// before the first one.
  final int? lastDoneAt;
```

and in `from`, track `int? last` over `done` tasks' `doneAt` (max), passing `lastDoneAt: last`.

`achievements_repository.dart`, add after `todayIsClear`:

```dart
  /// Today as the Today screen shows it: tasks due today or earlier, in a
  /// list that still exists, split into those completed today and those
  /// still open.
  Future<({int done, int open})> todayCounts() async {
    final today = dayStartMs(_now());
    final tomorrow = dayStartMsFrom(_now(), 1);
    final rows =
        await (_db.select(_db.tasks).join([
                innerJoin(
                  _db.lists,
                  _db.lists.id.equalsExp(_db.tasks.listId),
                  useColumns: false,
                ),
              ])
              ..where(
                _db.tasks.deletedAt.isNull() &
                    _db.lists.deletedAt.isNull() &
                    _db.tasks.dueAt.isNotNull() &
                    _db.tasks.dueAt.isSmallerThanValue(tomorrow) &
                    (_db.tasks.done.equals(false) |
                        _db.tasks.doneAt.isBiggerOrEqualValue(today)),
              ))
            .map((r) => r.readTable(_db.tasks))
            .get();
    final done = rows.where((t) => t.done).length;
    return (done: done, open: rows.length - done);
  }

  /// Tasks completed today, whatever their due date.
  Future<int> doneTodayCount() async {
    final today = dayStartMs(_now());
    final rows =
        await (_db.select(_db.tasks).join([
                innerJoin(
                  _db.lists,
                  _db.lists.id.equalsExp(_db.tasks.listId),
                  useColumns: false,
                ),
              ])
              ..where(
                _db.tasks.deletedAt.isNull() &
                    _db.lists.deletedAt.isNull() &
                    _db.tasks.done.equals(true) &
                    _db.tasks.doneAt.isBiggerOrEqualValue(today),
              ))
            .get();
    return rows.length;
  }
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/achievements` -- all pass. Format and analyze clean.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/achievements app/test/features/achievements
git commit -m "feat(app): count Today's progress and remember the last completion"
```

---

### Task 4: Controller attaches the message

**Files:**
- Modify: `app/lib/features/celebrations/ui/celebration_controller.dart`
- Modify: `app/lib/features/celebrations/ui/complete_task.dart`
- Test: `app/test/features/celebrations/celebration_controller_test.dart`

**Interfaces:**
- Consumes: Task 1 (`pickMotivation`, `MotivationContext`, `Motivation`), Task 3 (`todayCounts`, `doneTodayCount`, `stats().currentStreak`).
- Produces:
  - `class CelebrationCheer { const CelebrationCheer(this.motivation, this.context); final Motivation motivation; final MotivationContext context; }`
  - `TickCelebration({this.cheer, this.showPill = true})`, `DayClearedCelebration({this.cheer, this.showPill = true})` -- `CelebrationCheer? cheer`, `bool showPill`.
  - `CelebrationController(..., Random? random)`.
  - `Future<CelebrationEvent?> onCompleted(Task task, {Future<void> Function()? write, bool showPill = true})` -- returns the event emitted (null when none).
  - `Future<CelebrationCheer?> completeTask(WidgetRef ref, Task task, {required bool done, bool showPill = true})` -- the emitted cheer, null otherwise.

- [ ] **Step 1: Write the failing tests**

Add to `celebration_controller_test.dart` (the existing setUp builds the controller; pass `random: Random(1)` there), plus:

```dart
  CelebrationCheer? cheerOf(CelebrationEvent e) => switch (e) {
    TickCelebration(:final cheer) => cheer,
    DayClearedCelebration(:final cheer) => cheer,
    AchievementsUnlocked() => null,
  };

  test('a tick carries a message with Today\'s counts', () async {
    await tick(await add('Warm-up')); // unlocks first_done
    final a = await add('A', dueToday: true);
    await add('B', dueToday: true);
    await add('C', dueToday: true);
    await tick(a);
    final cheer = cheerOf(events.last)!;
    expect(cheer.context.todayDone, 1);
    expect(cheer.context.todayTotal, 3);
    expect(cheer.context.wasInToday, isTrue);
    expect(cheer.context.firstToday, isFalse, reason: 'Warm-up came first');
  });

  test('clearing the day carries the day-cleared message', () async {
    await tick(await add('Warm-up'));
    await tick(await add('B', dueToday: true)); // unlocks cleared_today
    await tick(await add('C', dueToday: true));
    final event = events.last as DayClearedCelebration;
    expect(event.cheer!.motivation.kind, MotivationKind.dayCleared);
  });

  test('no message with celebrations off, none on an unlock', () async {
    await tick(await add('First'));
    expect(events.single, isA<AchievementsUnlocked>());
    celebrate = false;
    await tick(await add('Second'));
    expect(events, hasLength(1));
  });

  test('onCompleted returns what it emitted, and passes showPill', () async {
    await tick(await add('Warm-up'));
    final t = await add('A');
    await tasks.setDone(t.id, done: true);
    final event = await controller.onCompleted(t, showPill: false);
    expect(event, isA<TickCelebration>());
    expect((event! as TickCelebration).showPill, isFalse);
  });
```

Imports: `dart:math`, `motivation.dart`.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/celebrations/celebration_controller_test.dart` -- compile errors (`cheer`, `showPill`, `random`).

- [ ] **Step 3: Implement**

In `celebration_controller.dart`:

```dart
/// What to say about a completion, with what it was said about.
class CelebrationCheer {
  const CelebrationCheer(this.motivation, this.context);

  final Motivation motivation;
  final MotivationContext context;
}

/// An ordinary completion.
class TickCelebration extends CelebrationEvent {
  const TickCelebration({this.cheer, this.showPill = true});

  /// Null when choosing a message failed.
  final CelebrationCheer? cheer;

  /// False when the caller shows [cheer] itself (the swipe's snackbar).
  final bool showPill;
}

/// The last open task Today showed is done.
class DayClearedCelebration extends CelebrationEvent {
  const DayClearedCelebration({this.cheer, this.showPill = true});

  final CelebrationCheer? cheer;
  final bool showPill;
}
```

Constructor gains `Random? random` stored as `_random = random ?? Random()`, and a field `final _recent = <Motivation>[];`.

`onCompleted`:

```dart
  Future<CelebrationEvent?> onCompleted(
    Task task, {
    Future<void> Function()? write,
    bool showPill = true,
  }) {
    CelebrationEvent? emitted;
    return _inTurn(() async {
      if (write != null) await write();
      emitted = await _celebrate(task, showPill: showPill);
    }).then((_) => emitted);
  }
```

`_celebrate(Task task, {required bool showPill})` returns `Future<CelebrationEvent?>`; in the event choice:

```dart
      } else if (cleared) {
        event = DayClearedCelebration(
          cheer: await _cheer(task, cleared: true, wasInToday: wasInToday),
          showPill: showPill,
        );
      } else {
        event = TickCelebration(
          cheer: await _cheer(task, cleared: false, wasInToday: wasInToday),
          showPill: showPill,
        );
      }
      if (event != null && !_events.isClosed) _events.add(event);
      return event;
```

(and `return null;` in the catch). Add:

```dart
  /// Picks what to say; null if gathering the context fails, so the tick
  /// still gets its bounce without words.
  Future<CelebrationCheer?> _cheer(
    Task task, {
    required bool cleared,
    required bool wasInToday,
  }) async {
    try {
      final counts = await _repo.todayCounts();
      final context = MotivationContext(
        todayDone: counts.done,
        todayTotal: counts.done + counts.open,
        wasInToday: wasInToday,
        firstToday: await _repo.doneTodayCount() == 1,
        streak: (await _repo.stats()).currentStreak,
        wasOverdue: task.dueAt != null && task.dueAt! < dayStartMs(_now()),
        cleared: cleared,
      );
      final motivation = pickMotivation(
        context,
        recent: _recent,
        random: _random,
      );
      _recent.add(motivation);
      if (_recent.length > motivationMemory) _recent.removeAt(0);
      return CelebrationCheer(motivation, context);
    } on Object catch (error, stack) {
      debugPrint('Choosing a message failed: $error\n$stack');
      return null;
    }
  }
```

`complete_task.dart`:

```dart
Future<CelebrationCheer?> completeTask(
  WidgetRef ref,
  Task task, {
  required bool done,
  bool showPill = true,
}) async {
  final tasks = ref.read(tasksRepositoryProvider);
  final celebrations = ref.read(celebrationControllerProvider);
  if (!done) {
    await tasks.setDone(task.id, done: false);
    return null;
  }
  final event = await celebrations.onCompleted(
    task,
    write: () => tasks.setDone(task.id, done: true),
    showPill: showPill,
  );
  return switch (event) {
    TickCelebration(:final cheer) => cheer,
    DayClearedCelebration(:final cheer) => cheer,
    _ => null,
  };
}
```

Update the doc comments. Existing `const TickCelebration()` / `const DayClearedCelebration()` uses elsewhere (overlay, tests) keep compiling.

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/celebrations` -- all pass, including existing controller and overlay tests. Format and analyze clean.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/celebrations app/test/features/celebrations
git commit -m "feat(app): attach a message to each celebrated completion"
```

---

### Task 5: The pill, and the swipe snackbar

**Files:**
- Create: `app/lib/features/celebrations/ui/motivation_pill.dart`
- Modify: `app/lib/features/celebrations/ui/celebration_overlay.dart`
- Modify: `app/lib/features/tasks/ui/task_list_view.dart`
- Test: `app/test/features/celebrations/celebration_overlay_test.dart`, and the swipe test file (find it with `grep -rln "tasksCompletedSnack\|Task completed" app/test`)

**Interfaces:**
- Consumes: `CelebrationCheer`, `TickCelebration.showPill`/`.cheer`, `DayClearedCelebration.showPill`/`.cheer` (Task 4); `motivationText` (Task 2); `completeTask(..., showPill:)` returning `CelebrationCheer?` (Task 4).
- Produces: `MotivationPill({required String text, required bool visible, required bool animate})` keyed `motivation-pill` by the overlay.

- [ ] **Step 1: Write the failing tests**

In `celebration_overlay_test.dart`, using its `seedToday` and `tickOff` helpers and the file's existing `pumpApp` call pattern (switches through the `kv` map as other tests there do):

```dart
  appTest('a tick shows a message pill that goes away', (tester) async {
    // three tasks so the second tick is an ordinary one
    ... pump the app on Today with seedToday(['A', 'B', 'C']) as other tests do
    await tickOff(tester, 'A'); // first achievement: banner, no pill
    expect(find.byKey(const Key('motivation-pill')), findsNothing);
    await tickOff(tester, 'B');
    expect(find.byKey(const Key('motivation-pill')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('motivation-pill')),
        matching: find.byType(Text),
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const Key('motivation-pill')), findsNothing);
  });

  appTest('the pill never blocks a tap', ...)
    // after a tick, tap the next DoneCheck where the pill might overlap:
    // expect the task to be done (IgnorePointer). Simplest check:
    // tester.widget<IgnorePointer>(find.ancestor(of: pill, matching: find.byType(IgnorePointer)).first).ignoring == true

  appTest('the pill is a live region', ...)
    // find.ancestor(of: pill text, matching: find.byWidgetPredicate((w) => w is Semantics && w.properties.liveRegion == true))

  appTest('with celebrations off there is no pill', ...)
    // kv: {KvKeys.celebrationsEnabled: 'false'} (use the key the settings controller reads; see existing tests in this file)

  appTest('reduced motion shows the pill without fading', ...)
    // tester.platformDispatcher.accessibilityFeaturesTestValue = FakeAccessibilityFeatures(disableAnimations: true), reset in finally/addTearDown as the file does elsewhere
    // after one pump the pill's Opacity/FadeTransition is fully opaque
```

Fill each `...` with the same setup code the file's existing tests use (read it first); the assertions are as commented.

In the swipe test file, add: swiping a task to complete (with at least one earlier completion so no achievement unlocks) shows a snackbar whose text is not "Task completed" and shows no `motivation-pill`; with Celebrations off, the snackbar says "Task completed".

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/celebrations/celebration_overlay_test.dart` -- new tests fail (no pill).

- [ ] **Step 3: Implement the pill**

```dart
// app/lib/features/celebrations/ui/motivation_pill.dart
import 'package:flutter/material.dart';

/// A short message after a completion: small, calm, out of the way.
///
/// Ignores pointers so it never takes the next tap, and is a live region
/// so a screen reader reads it out.
class MotivationPill extends StatelessWidget {
  const MotivationPill({
    required this.text,
    required this.visible,
    required this.animate,
    super.key,
  });

  final String text;
  final bool visible;

  /// False under reduced motion: the pill appears and goes without a fade.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: animate
            ? Duration(milliseconds: visible ? 150 : 200)
            : Duration.zero,
        child: Semantics(
          liveRegion: true,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Material(
              color: scheme.inverseSurface,
              elevation: 3,
              shape: const StadiumBorder(),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: scheme.inversePrimary,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          color: scheme.onInverseSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Show it from the overlay**

In `_CelebrationOverlayState`: fields `String? _pillText; bool _pillVisible = false; Timer? _hidePill; Timer? _removePill;` (cancel both in `dispose`).

At the top of `_show`, after the `mounted` check and before `big`:

```dart
    final cheer = switch (event) {
      TickCelebration(:final cheer, :final showPill) when showPill => cheer,
      DayClearedCelebration(:final cheer, :final showPill) when showPill =>
        cheer,
      _ => null,
    };
    if (cheer != null && ref.read(celebrationsEnabledProvider)) {
      _showPill(motivationText(L.of(context), cheer.motivation, cheer.context));
    }
```

`L.of(context)` works here because the overlay sits inside `MaterialApp.builder`, below `Localizations`; if it does not (check where `CelebrationOverlay` is inserted in `app.dart`), read `Localizations.of<L>(context, L)` inside `_buildLayer` instead and store the cheer rather than the text.

```dart
  void _showPill(String text) {
    _hidePill?.cancel();
    _removePill?.cancel();
    _pillText = text;
    _pillVisible = true;
    _layer.markNeedsBuild();
    _hidePill = Timer(const Duration(milliseconds: 2650), () {
      if (!mounted) return;
      _pillVisible = false;
      _layer.markNeedsBuild();
      _removePill = Timer(const Duration(milliseconds: 200), () {
        if (!mounted) return;
        _pillText = null;
        _layer.markNeedsBuild();
      });
    });
  }
```

(2650 ms = 150 ms fade-in + 2.5 s hold.)

In `_buildLayer`'s `Stack` children, add:

```dart
        if (_pillText case final text?)
          Positioned(
            left: 16,
            right: 16,
            // Above the navigation bar and the quick-add bar under it.
            bottom:
                MediaQuery.paddingOf(context).bottom +
                kBottomNavigationBarHeight +
                72,
            child: Center(
              child: MotivationPill(
                key: const Key('motivation-pill'),
                text: text,
                visible: _pillVisible,
                animate: !MediaQuery.disableAnimationsOf(context),
              ),
            ),
          ),
```

Check the offset visually against the Today screen (quick-add bar + navigation bar) in the widget test by asserting the pill's rect does not overlap the `NavigationBar`'s rect (`tester.getRect`), and adjust the constant if it does.

- [ ] **Step 5: Swipe snackbar**

In `task_list_view.dart`'s `confirmDismiss`, completing branch:

```dart
          final cheer = await completeTask(
            ref,
            task,
            done: !task.done,
            showPill: false,
          );
          if (!task.done) {
            final celebrate = ref.read(celebrationsEnabledProvider);
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  celebrate && cheer != null && context.mounted
                      ? motivationText(l, cheer.motivation, cheer.context)
                      : l.tasksCompletedSnack,
                ),
                action: ...unchanged...
```

Read `celebrationsEnabledProvider` before the `await` (with the repositories), since `ref` may be gone after it; the `l` already in scope is fine to use after the await.

- [ ] **Step 6: Run to verify pass**

Run: `flutter test test/features/celebrations` then `flutter test test/features/tasks` -- all pass. Format and analyze clean.

- [ ] **Step 7: Commit**

```bash
git add app/lib/features/celebrations app/lib/features/tasks/ui/task_list_view.dart app/test/features/celebrations app/test/features/tasks
git commit -m "feat(app): show a short message after each completed task"
```

---

### Task 6: Today progress header

**Files:**
- Create: `app/lib/features/tasks/ui/today_progress.dart`
- Modify: `app/lib/features/tasks/ui/today_screen.dart`
- Test: `app/test/features/tasks/today_progress_test.dart`

**Interfaces:**
- Consumes: `todayLineText`, `TodayLine` (Task 2); `CompletionStats.lastDoneAt` (Task 3); `achievementsRepositoryProvider`'s `watchStats()` (existing: find the provider exposing it in `achievements_providers.dart`, or watch `ref.watch(achievementsRepositoryProvider).watchStats()` through a `StreamProvider` added there); `celebrationsEnabledProvider`; `nowProvider`.
- Produces: `TodayProgress({required List<Task> items})` -- `items` is the list `TodayScreen` already has (open Today tasks plus tasks completed today). Keys: `today-progress`, `today-progress-bar`, `today-progress-line`.

Rules:
- `total = items.length`, `done = items.where((t) => t.done).length`. Hidden (`SizedBox.shrink()`) when `total == 0`.
- Bar: `LinearProgressIndicator(value: done / total, minHeight: 4, borderRadius: BorderRadius.circular(2))` and `l.todayProgressCount(done, total)` in `labelMedium`, `onSurfaceVariant`, on one row (bar `Expanded`, count after it).
- Line (only when Celebrations is on), `bodySmall`, `onSurfaceVariant`, below the row:
  - `done == total`: `TodayLine.allClear`.
  - `done == 0` and `lastDoneAt != null` and the last completion's local day is 3 or more calendar days before today: `TodayLine.welcomeBack`.
  - `done == 0` otherwise: `TodayLine.freshStart`.
  - else none.
  - `dayOfYear` = `now.difference(DateTime(now.year)).inDays`.
- Padding: `EdgeInsets.fromLTRB(16, 8, 16, 4)`; inside the same `MaxWidth` as the list.

- [ ] **Step 1: Write the failing tests**

`today_progress_test.dart` with `pumpApp(tester, initialLocation: Routes.today)` (the harness's `testNow` clock) and seeded tasks:
- no tasks due today: `today-progress` finds nothing;
- 3 due today, 1 done: bar value `1/3`, text "1 of 3 done", no line;
- 3 due today, none done, a completion yesterday: "A fresh start." / "Pick one to begin." / "One thing at a time." (whichever `dayOfYear` picks -- compute it in the test from `testNow`);
- none done today, last completion 4 days ago: the welcome-back line for that day;
- all done: "All clear. Enjoy the rest of your day.";
- Celebrations off (kv switch as other tests set it): bar and count shown, `today-progress-line` finds nothing.

Seed completed tasks with explicit `doneAt` by writing rows through `app.db.upsertTask(Task(..., done: true, doneAt: ...))` so dates in the past are possible.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/tasks/today_progress_test.dart` -- `today_progress.dart` not found.

- [ ] **Step 3: Implement**

`TodayProgress` as a `ConsumerWidget` following the rules above. For `lastDoneAt`, watch a `StreamProvider<CompletionStats>` over `watchStats()` (add `completionStatsProvider` to `achievements_providers.dart` if none exists; it is a plain `StreamProvider`, no codegen needed). While loading, treat `lastDoneAt` as null (fresh start line).

In `TodayScreen`, inside the `AsyncBody` `data` builder, return a `Column` with `TodayProgress(items: items)` and `Expanded(child: TaskListView(...))` when `items` is not empty (the empty-state branch stays as is). If `TaskListView` already applies `MaxWidth`, wrap `TodayProgress` in `MaxWidth` too so both line up.

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/tasks` -- all pass (existing Today tests included). Format and analyze clean.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/tasks/ui/today_progress.dart app/lib/features/tasks/ui/today_screen.dart app/lib/features/achievements/ui/achievements_providers.dart app/test/features/tasks/today_progress_test.dart
git commit -m "feat(app): show Today's progress with a calm word of encouragement"
```

---

### Task 7: Changelog and full verification

**Files:**
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Changelog**

Under the intro, above `## 0.12.0 - 2026-09-24`:

```markdown
## Unreleased

### Added

- Ticking a task off now shows a short, varied message: a word of
  encouragement, how far along today is, "one to go", or a note when a
  streak continues. Swiping a task done puts the message in the Undo bar.
- The Today screen shows how many of today's tasks are done, with a calm
  line to start the day, a welcome back after a break, and a note when
  everything is done. Messages follow the Celebrations switch in Settings.
```

- [ ] **Step 2: Full check**

One at a time:

```bash
dart format --set-exit-if-changed lib test
flutter analyze
flutter test --concurrency=2 test/features/celebrations
flutter test --concurrency=2 test/features/tasks
flutter test --concurrency=2 --exclude-tags design
```

Expected: clean, all pass.

- [ ] **Step 3: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: motivation messages in the changelog"
```
