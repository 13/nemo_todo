# Task Work Fields Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a task record what it took — how it was solved, how many minutes it took, and what it cost — as three optional fields kept out of the way until one is filled in.

**Architecture:** Three columns on `Task` rather than a new entity, so everything sync already does for a task does the right thing for them. Time and money are stored as integers (whole minutes, minor units) and parsed once at the edge by two pure functions, so sync, export and SQLite can never round them differently. The currency is a device-local setting beside the theme, because this app has no synced settings channel and a display symbol does not justify inventing one.

**Tech Stack:** Dart 3.13, Flutter 3.47.2, drift (SQLite on both sides), freezed + json_serializable, riverpod, `intl` (already a direct dependency at ^0.20.2).

## Global Constraints

- Spec: `docs/superpowers/specs/2026-09-22-task-work-fields-design.md`. Read it before Task 1.
- Flutter and Dart are not on `PATH`. Every shell starts with `export PATH="$HOME/fvm/versions/3.47.2/bin:$PATH"`, including the one you commit from — the pre-commit hook runs the generators and fails without it.
- **Never background a test run.** Foreground, 600s timeout, one test process at a time: this machine OOM-kills concurrent Flutter suites, which is also why the app suite runs `--concurrency=2`.
- `flutter analyze` must exit 0. Capture it as `flutter analyze > /tmp/analyze.txt 2>&1; echo "EXIT=$?"` — piping to `tail` reports tail's status, not analyze's.
- Baselines before this plan: nemo_core 59, server 121, app 413.
- Row classes live in `packages/nemo_core`; the identical drift table is declared **twice**, in `app/lib/core/db/sync_tables.dart` and `server/lib/src/db/sync_tables.dart`. Both must match the row class constructor exactly or drift refuses to generate.
- `very_good_analysis` requires every `required` named parameter before any optional one.
- Generated code and drift schema snapshots are committed. A table change means `drift_dev schema dump` on both sides and `schema generate` for the server.
- Every user-visible string goes through `l10n` in all three locales: `app/lib/l10n/app_en.arb`, `app_de.arb`, `app_it.arb`, then `cd app && flutter gen-l10n`.
- Append tests; never rewrite a test file. A regression test was silently lost that way on the previous feature.
- `dart format` over `lib` and `test` in every package touched — the CI format check has caught this before.
- Stage by explicit path; run `git status --short` first.
- Conventional Commits, each message ending with BOTH lines verbatim:

```
Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01JK6GttYNgLykt2Ps5g5g6z
```

## File Structure

**Created**

| Path | Responsibility |
|---|---|
| `app/lib/utils/work_input.dart` | `parseMinutes`, `parseMinorUnits`, and their formatters |
| `app/test/utils/work_input_test.dart` | Their tests |
| `app/lib/features/tasks/ui/task_work_section.dart` | The collapsed/expanded section on the task page |
| `app/lib/features/settings/ui/currency_tile.dart` | The Settings currency picker |

**Modified**

| Path | Change |
|---|---|
| `packages/nemo_core/lib/src/model/task.dart` | Three fields |
| `app/lib/core/db/sync_tables.dart`, `server/lib/src/db/sync_tables.dart` | Three columns |
| `app/lib/core/db/app_database.dart` | Schema 4 → 5 |
| `server/lib/src/db/server_database.dart` | Schema 5 → 6 |
| `app/lib/features/tasks/data/tasks_repository.dart` | Reset on repeat; search `solution` |
| `app/lib/features/tasks/ui/task_detail_screen.dart` | Place the section |
| `app/lib/core/providers.dart` | `currency` in `AppBootstrap` |
| `app/lib/core/db/kv_store.dart` | `KvKeys.currency` |
| `app/lib/features/settings/ui/settings_controller.dart` | `CurrencyCode` controller |
| `app/lib/features/settings/ui/settings_screen.dart` | Place the tile |
| `app/lib/l10n/*.arb` | New strings |

---

### Task 1: The three fields on `Task`

**Files:**
- Modify: `packages/nemo_core/lib/src/model/task.dart`
- Test: `packages/nemo_core/test/model_test.dart`

**Interfaces:**
- Produces: `Task.solution` (`String`, defaults `''`), `Task.timeSpentMinutes` (`int?`), `Task.costMinor` (`int?`), serialising as `solution`, `time_spent_minutes`, `cost_minor`.

- [ ] **Step 1: Branch**

```bash
git switch -c feat/task-work-fields
export PATH="$HOME/fvm/versions/3.47.2/bin:$PATH"
```

- [ ] **Step 2: Write the failing test**

Append to `packages/nemo_core/test/model_test.dart`:

```dart
  test('a task carries what it took, and what it costs to omit', () {
    const task = Task(
      id: 't1',
      listId: 'l1',
      title: 'Fix the tap',
      solution: 'New washer, 12 mm',
      timeSpentMinutes: 90,
      costMinor: 1250,
      sortKey: 'V',
      updatedAt: '0000000000001-0000-n',
    );

    final json = jsonDecode(jsonEncode(task.toJson())) as Map<String, dynamic>;

    expect(json['solution'], 'New washer, 12 mm');
    expect(json['time_spent_minutes'], 90);
    expect(json['cost_minor'], 1250);
    expect(Task.fromJson(json), task);
  });

  test('a task from before these fields reads as empty and unrecorded', () {
    final json = {
      'id': 't1',
      'list_id': 'l1',
      'title': 'Fix the tap',
      'sort_key': 'V',
      'updated_at': '0000000000001-0000-n',
    };

    final task = Task.fromJson(json);

    expect(task.solution, '');
    expect(
      task.timeSpentMinutes,
      isNull,
      reason: 'nobody recorded a time, which is not the same as zero',
    );
    expect(task.costMinor, isNull);
  });
```

- [ ] **Step 3: Run it to make sure it fails**

Run: `cd packages/nemo_core && dart test test/model_test.dart`
Expected: FAIL — `No named parameter with the name 'solution'`.

- [ ] **Step 4: Add the fields**

In `packages/nemo_core/lib/src/model/task.dart`, inside the `const factory Task(...)`, after the existing `@Default(<String>[]) List<String> tags,` and before `String? repeat,` — every `required` parameter already sits above them, and `very_good_analysis` demands it stay that way:

```dart
    /// How the task was solved, in the person's own words. Empty rather
    /// than null, like [notes], so no reader needs a null check.
    @Default('') String solution,

    /// Whole minutes. Null means nobody recorded a time, which is not the
    /// same as recording that it took none.
    int? timeSpentMinutes,

    /// What it cost, in the minor unit of the currency the app is set to.
    /// An integer, so the amount survives sync, export and SQLite
    /// unrounded. Null means nothing was recorded.
    int? costMinor,
```

- [ ] **Step 5: Generate and run**

```bash
cd packages/nemo_core && dart run build_runner build --delete-conflicting-outputs
dart test
```
Expected: PASS, whole package (61 tests).

- [ ] **Step 6: Commit**

```bash
git add packages/nemo_core/lib packages/nemo_core/test/model_test.dart
git commit -m "$(cat <<'EOF'
feat(core): let a task record its solution, time and cost

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01JK6GttYNgLykt2Ps5g5g6z
EOF
)"
```

---

### Task 2: Both schemas

**Files:**
- Modify: `app/lib/core/db/sync_tables.dart`, `server/lib/src/db/sync_tables.dart`
- Modify: `app/lib/core/db/app_database.dart`, `server/lib/src/db/server_database.dart`
- Test: `app/test/core/db/migration_test.dart`, `server/test/migration_test.dart`

**Interfaces:**
- Consumes: `Task.solution`, `Task.timeSpentMinutes`, `Task.costMinor` (Task 1).
- Produces: app schema 5, server schema 6; `tasks.solution`, `tasks.timeSpentMinutes`, `tasks.costMinor` columns.

- [ ] **Step 1: Write the failing migration test**

Append to `app/test/core/db/migration_test.dart`:

```dart
  test('a task survives the v5 migration unrecorded', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(4);
    schema.rawDatabase.execute(
      'insert into tasks (id, list_id, title, tags, sort_key, updated_at) '
      'values (?, ?, ?, ?, ?, ?)',
      ['t1', 'l1', 'Fix the tap', '[]', 'V', '0000000000001-0000-n'],
    );
    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 5);

    final row = await db.taskById('t1');

    expect(row!.solution, '');
    expect(row.timeSpentMinutes, isNull);
    expect(row.costMinor, isNull);
    await db.close();
  });
```

Also extend the file's existing "migrates a database from every earlier version" loop to `for (final from in [1, 2, 3, 4])` with `migrateAndValidate(db, 5)`, and change the index test's target version to 5. Do the same two edits in `server/test/migration_test.dart` (loop `[1, 2, 3, 4, 5]`, target 6) and append the server twin of the test above, using `ServerDatabase(schema.newConnection())`, `verifier.schemaAt(5)` and `migrateAndValidate(db, 6)`.

- [ ] **Step 2: Run it to make sure it fails**

Run: `cd app && flutter test test/core/db/migration_test.dart`
Expected: FAIL — the schema has no version 5 (`Expected schema version 5`).

- [ ] **Step 3: Add the columns to both tables**

In **both** `app/lib/core/db/sync_tables.dart` and `server/lib/src/db/sync_tables.dart`, inside `class Tasks extends Table`, after `TextColumn get notes => ...`:

```dart
  TextColumn get solution => text().withDefault(const Constant(''))();
  IntColumn get timeSpentMinutes => integer().nullable()();
  IntColumn get costMinor => integer().nullable()();
```

- [ ] **Step 4: Both migrations**

In `app/lib/core/db/app_database.dart`, set `int get schemaVersion => 5;` and add at the end of `onUpgrade`:

```dart
      // Version 5 records what a task took. Every existing row is already
      // valid without a backfill: solution defaults to empty, and a null
      // time or cost is exactly what "nobody wrote one down" means. No
      // cursor reset either -- these ride on the task row a client already
      // receives, so there is nothing the server skipped for this device.
      if (from < 5) {
        await m.addColumn(tasks, tasks.solution);
        await m.addColumn(tasks, tasks.timeSpentMinutes);
        await m.addColumn(tasks, tasks.costMinor);
      }
```

In `server/lib/src/db/server_database.dart`, set `int get schemaVersion => 6;` and add the identical block guarded `if (from < 6)`.

- [ ] **Step 5: Regenerate and dump both schemas**

```bash
cd app && dart run build_runner build --delete-conflicting-outputs
dart run drift_dev schema dump lib/core/db/app_database.dart drift_schemas/
cd ../server && dart run build_runner build --delete-conflicting-outputs
dart run drift_dev schema dump lib/src/db/server_database.dart drift_schemas/
dart run drift_dev schema generate drift_schemas/ test/generated/
```
Expected: `app/drift_schemas/drift_schema_v5.json`, `server/drift_schemas/drift_schema_v6.json` and `server/test/generated/schema_v6.dart` appear. The app also needs its generated helper: `cd app && dart run drift_dev schema generate drift_schemas/ test/generated/`.

- [ ] **Step 6: Run both migration suites**

```bash
cd app && flutter test test/core/db/migration_test.dart
cd ../server && dart test test/migration_test.dart
```
Expected: PASS both.

- [ ] **Step 7: Commit**

```bash
git add app/lib app/drift_schemas app/test server/lib server/drift_schemas server/test
git commit -m "$(cat <<'EOF'
feat(db): carry a task's solution, time and cost in both schemas

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01JK6GttYNgLykt2Ps5g5g6z
EOF
)"
```

---

### Task 3: Reading what a person typed

**Files:**
- Create: `app/lib/utils/work_input.dart`, `app/test/utils/work_input_test.dart`

**Interfaces:**
- Produces: `int? parseMinutes(String)`, `int? parseMinorUnits(String, {required String locale})`, `String formatMinutes(int, {required String hoursLabel, required String minutesLabel})`, `String formatMoney(int minor, {required String currency, required String locale})`.

The parsers are the whole point of this task: they are where a typo becomes wrong stored data. `app/lib/utils/quick_add_parser.dart` is the precedent — a pure function over what a person typed, tested on its own rather than through a widget.

- [ ] **Step 1: Write the failing tests**

Create `app/test/utils/work_input_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/utils/work_input.dart';

void main() {
  group('parseMinutes', () {
    test('reads bare minutes', () {
      expect(parseMinutes('90'), 90);
      expect(parseMinutes(' 90 '), 90);
      expect(parseMinutes('0'), 0);
    });

    test('reads hours and minutes however they are written', () {
      expect(parseMinutes('1h 30'), 90);
      expect(parseMinutes('1h30'), 90);
      expect(parseMinutes('1:30'), 90);
      expect(parseMinutes('2h'), 120);
      expect(parseMinutes('45m'), 45);
      expect(parseMinutes('1 h 5 m'), 65);
    });

    test('refuses what it cannot read rather than guessing', () {
      expect(parseMinutes(''), isNull);
      expect(parseMinutes('   '), isNull);
      expect(parseMinutes('a while'), isNull);
      expect(parseMinutes('-5'), isNull);
      expect(parseMinutes('1:90'), isNull, reason: '90 is not a minute count');
    });
  });

  group('parseMinorUnits', () {
    test('reads a decimal in the locale that wrote it', () {
      expect(parseMinorUnits('12.50', locale: 'en'), 1250);
      expect(parseMinorUnits('12,50', locale: 'de'), 1250);
      expect(parseMinorUnits('12', locale: 'en'), 1200);
      expect(parseMinorUnits('0', locale: 'en'), 0);
      expect(parseMinorUnits('12.5', locale: 'en'), 1250);
    });

    test('refuses what it cannot read rather than guessing', () {
      expect(parseMinorUnits('', locale: 'en'), isNull);
      expect(parseMinorUnits('lots', locale: 'en'), isNull);
      expect(parseMinorUnits('-3', locale: 'en'), isNull);
      expect(parseMinorUnits('12.505', locale: 'en'), isNull,
          reason: 'more precision than the currency has');
    });
  });

  group('formatting', () {
    test('formatMinutes writes hours and minutes', () {
      expect(formatMinutes(90, hoursLabel: 'h', minutesLabel: 'min'),
          '1 h 30 min');
      expect(formatMinutes(45, hoursLabel: 'h', minutesLabel: 'min'), '45 min');
      expect(formatMinutes(120, hoursLabel: 'h', minutesLabel: 'min'), '2 h');
      expect(formatMinutes(0, hoursLabel: 'h', minutesLabel: 'min'), '0 min');
    });

    test('formatMoney writes the amount the locale would', () {
      expect(formatMoney(1250, currency: 'EUR', locale: 'de'), contains('12'));
      expect(formatMoney(1250, currency: 'EUR', locale: 'de'), contains('50'));
    });
  });
}
```

- [ ] **Step 2: Run them to make sure they fail**

Run: `cd app && flutter test test/utils/work_input_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:nemo/utils/work_input.dart'`.

- [ ] **Step 3: Write the parsers**

Create `app/lib/utils/work_input.dart`:

```dart
import 'package:intl/intl.dart';

/// Reads `90`, `1h 30`, `1h30`, `1:30`, `2h` or `45m` as whole minutes.
///
/// Returns null for anything it cannot read, so a slip leaves whatever
/// was stored alone rather than overwriting it with a zero nobody meant.
int? parseMinutes(String input) {
  final text = input.trim().toLowerCase();
  if (text.isEmpty) return null;

  final bare = RegExp(r'^\d+$').firstMatch(text);
  if (bare != null) return int.parse(text);

  final colon = RegExp(r'^(\d+):([0-5]?\d)$').firstMatch(text);
  if (colon != null) {
    return int.parse(colon.group(1)!) * 60 + int.parse(colon.group(2)!);
  }

  final parts = RegExp(r'^(?:(\d+)\s*h)?\s*(?:(\d+)\s*m?)?$').firstMatch(text);
  if (parts == null) return null;
  final hours = parts.group(1);
  final minutes = parts.group(2);
  if (hours == null && minutes == null) return null;
  final total =
      (hours == null ? 0 : int.parse(hours) * 60) +
      (minutes == null ? 0 : int.parse(minutes));
  return total;
}

/// Reads an amount written the way [locale] writes one -- `12.50` or
/// `12,50` -- as minor units, so 12.50 euro is 1250.
///
/// Returns null for anything it cannot read, and for more decimal places
/// than the minor unit has: 12.505 is a typo, not an amount.
int? parseMinorUnits(String input, {required String locale}) {
  final text = input.trim();
  if (text.isEmpty) return null;
  final separator = NumberFormat.decimalPattern(locale).symbols.DECIMAL_SEP;
  final normalised = text.replaceAll(separator, '.');
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(normalised)) return null;
  final value = double.parse(normalised);
  return (value * 100).round();
}

/// `1 h 30 min`, `45 min`, `2 h`. Labels come from the l10n catalogue so
/// each language writes its own.
String formatMinutes(
  int minutes, {
  required String hoursLabel,
  required String minutesLabel,
}) {
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (hours == 0) return '$rest $minutesLabel';
  if (rest == 0) return '$hours $hoursLabel';
  return '$hours $hoursLabel $rest $minutesLabel';
}

/// The amount as [locale] would write it, with [currency]'s symbol.
String formatMoney(
  int minor, {
  required String currency,
  required String locale,
}) => NumberFormat.simpleCurrency(
  locale: locale,
  name: currency,
).format(minor / 100);
```

- [ ] **Step 4: Run the tests**

Run: `cd app && flutter test test/utils/work_input_test.dart`
Expected: PASS, 7 tests.

- [ ] **Step 5: Commit**

```bash
git add app/lib/utils/work_input.dart app/test/utils/work_input_test.dart
git commit -m "$(cat <<'EOF'
feat(app): read a typed time and amount exactly

Both return null rather than guessing, so a slip leaves what was stored
alone instead of overwriting it with a zero nobody meant.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01JK6GttYNgLykt2Ps5g5g6z
EOF
)"
```

---

### Task 4: A repeating task starts clean, and search reads the solution

**Files:**
- Modify: `app/lib/features/tasks/data/tasks_repository.dart`
- Test: `app/test/features/tasks_repository_test.dart`

**Interfaces:**
- Consumes: `Task.solution`, `Task.timeSpentMinutes`, `Task.costMinor` (Task 1); `likePattern`/`likeEscapeChar` from `app/lib/core/db/like_pattern.dart` (already in the tree).

- [ ] **Step 1: Write the failing tests**

Append to `app/test/features/tasks_repository_test.dart`:

```dart
  test('the next occurrence of a repeating task starts unrecorded', () async {
    final task = await repository.create(
      listId: 'l1',
      title: 'Change the filter',
      dueAt: testNow.millisecondsSinceEpoch,
      repeat: const Repeat(every: RepeatUnit.month, interval: 1),
    );
    await repository.save(
      task.copyWith(
        solution: 'Second filter from the box',
        timeSpentMinutes: 20,
        costMinor: 1499,
      ),
    );

    await repository.setDone(task.id, done: true);

    final spawned = (await repository.watchByList('l1').first)
        .firstWhere((t) => t.id != task.id);
    expect(spawned.solution, '');
    expect(spawned.timeSpentMinutes, isNull);
    expect(
      spawned.costMinor,
      isNull,
      reason: 'they describe the occurrence that was done, not the rule',
    );
    expect((await db.taskById(task.id))!.solution, 'Second filter from the box',
        reason: 'the completed one keeps its own history');
  });

  test('search finds a task by a word only its solution has', () async {
    final task = await repository.create(listId: 'l1', title: 'Fix the tap');
    await repository.save(task.copyWith(solution: 'New washer, 12 mm'));

    expect(
      [for (final t in await repository.search('washer').first) t.title],
      ['Fix the tap'],
    );
  });
```

Match the `Repeat` constructor to what `packages/nemo_core/lib/src/repeat.dart` actually declares — read it first, and use whatever the file's existing repeat tests use.

- [ ] **Step 2: Run them to make sure they fail**

Run: `cd app && flutter test test/features/tasks_repository_test.dart`
Expected: FAIL — the spawned task carries `Second filter from the box`, and the search returns `[]`.

- [ ] **Step 3: Reset the three on the next occurrence**

In `tasks_repository.dart`, inside `_spawnRepeat`, the `next` is built with `copyWith`. Add the three resets beside the existing `done: false` and `doneAt: null`:

```dart
    final next = task.copyWith(
      id: _newId(),
      done: false,
      doneAt: null,
      // What it took describes the occurrence that was completed, not the
      // rule -- a fresh one has taken no time and cost nothing yet.
      solution: '',
      timeSpentMinutes: null,
      costMinor: null,
      dueAt: rule.nextDueAt(dueAt: dueAt, after: _now()),
      sortKey: await nextSortKey(task.listId),
      updatedAt: _clock.now().toString(),
    );
```

`copyWith` on a freezed class cannot set a nullable field back to null through a plain value, so if the generated `copyWith` refuses `timeSpentMinutes: null`, construct `next` with the full `Task(...)` constructor instead, copying each field explicitly. Say in your report which of the two you had to use.

- [ ] **Step 4: Add `solution` to the search**

In the same file, `search` builds its filter over title, notes and tags. Add the solution:

```dart
    return _visible(
      _db.tasks.title.like(pattern, escapeChar: likeEscapeChar) |
          _db.tasks.notes.like(pattern, escapeChar: likeEscapeChar) |
          _db.tasks.solution.like(pattern, escapeChar: likeEscapeChar) |
          _db.tasks.tags.like(pattern, escapeChar: likeEscapeChar),
      [OrderingTerm.asc(_db.tasks.done), OrderingTerm.asc(_db.tasks.title)],
    );
```

Read the current lines before editing — they already pass `escapeChar`, and the pattern variable already comes from the shared helper. Keep both.

- [ ] **Step 5: Run the tests**

Run: `cd app && flutter test test/features/tasks_repository_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/tasks/data/tasks_repository.dart app/test/features/tasks_repository_test.dart
git commit -m "$(cat <<'EOF'
feat(app): start a repeating task unrecorded, and search its solution

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01JK6GttYNgLykt2Ps5g5g6z
EOF
)"
```

---

### Task 5: The currency setting

**Files:**
- Modify: `app/lib/core/db/kv_store.dart`, `app/lib/core/providers.dart`, `app/lib/features/settings/ui/settings_controller.dart`, `app/lib/features/settings/ui/settings_screen.dart`, `app/lib/l10n/*.arb`
- Create: `app/lib/features/settings/ui/currency_tile.dart`
- Test: `app/test/features/settings/currency_tile_test.dart`

**Interfaces:**
- Produces: `KvKeys.currency`, `AppBootstrap.currency` (`String`), `currencyCodeProvider` exposing the code and a `set(String)`.
- Consumes: `formatMoney` (Task 3) only in Task 6.

- [ ] **Step 1: Write the failing test**

Create `app/test/features/settings/currency_tile_test.dart`, following `app/test/features/settings/data_tiles_test.dart` for the harness:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/kv_store.dart';

import '../../support/pump_app.dart';

void main() {
  testWidgets('choosing a currency keeps it', (tester) async {
    final harness = await pumpApp(tester, initialLocation: '/settings');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('currency-tile')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('USD').last);
    await tester.pumpAndSettle();

    expect(await KvStore(harness.db).get(KvKeys.currency), 'USD');
    expect(find.textContaining('USD'), findsWidgets);
  });
}
```

- [ ] **Step 2: Run it to make sure it fails**

Run: `cd app && flutter test test/features/settings/currency_tile_test.dart`
Expected: FAIL — no widget with key `currency-tile`.

- [ ] **Step 3: Store and load the code**

`app/lib/core/db/kv_store.dart`, in `KvKeys`:

```dart
  /// ISO 4217 code the amounts on a task are written in. Device-local,
  /// like every other setting here.
  static const currency = 'currency';
```

`app/lib/core/providers.dart`, in `AppBootstrap`: add `this.currency = 'EUR',` to the constructor (after `achievements`), the field

```dart
  /// ISO 4217 code for the amounts on a task; the device's own locale
  /// decides the default the first time.
  final String currency;
```

and in `load`:

```dart
      currency: await kv.get(KvKeys.currency) ?? defaultCurrencyCode(),
```

with the helper beside `AppBootstrap` in the same file:

```dart
/// What the device's own locale spends in, for the first run. Falls back
/// to EUR when the locale names no currency.
String defaultCurrencyCode() {
  try {
    return NumberFormat.simpleCurrency(
          locale: Intl.getCurrentLocale(),
        ).currencyName ??
        'EUR';
  } on Exception {
    // An unknown locale: a default the user can change beats a crash on
    // the first frame.
    return 'EUR';
  }
}
```

This needs `import 'package:intl/intl.dart';` at the top of `providers.dart`.

- [ ] **Step 4: The controller**

In `app/lib/features/settings/ui/settings_controller.dart`, beside `CelebrationsEnabled`:

```dart
/// Which currency the amounts on a task are written in.
@Riverpod(keepAlive: true)
class CurrencyCode extends _$CurrencyCode {
  @override
  String build() => ref.watch(bootstrapProvider).currency;

  Future<void> set(String code) async {
    state = code;
    await ref.read(kvStoreProvider).set(KvKeys.currency, code);
  }
}
```

Then `cd app && dart run build_runner build --delete-conflicting-outputs`.

- [ ] **Step 5: The tile**

Create `app/lib/features/settings/ui/currency_tile.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/features/settings/ui/settings_controller.dart';
import 'package:nemo/l10n/app_localizations.dart';

/// The currency the amounts on a task are written in.
///
/// A short list rather than every ISO code: a household spends in one,
/// and the code it already holds is always offered even when it is not
/// on the list.
const _offered = ['EUR', 'USD', 'GBP', 'CHF', 'SEK', 'NOK', 'DKK', 'PLN'];

class CurrencyTile extends ConsumerWidget {
  const CurrencyTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final current = ref.watch(currencyCodeProvider);
    final codes = [
      if (!_offered.contains(current)) current,
      ..._offered,
    ];
    return ListTile(
      key: const Key('currency-tile'),
      leading: const Icon(Icons.payments_outlined),
      title: Text(l.settingsCurrency),
      subtitle: Text(current),
      onTap: () async {
        final chosen = await showModalBottomSheet<String>(
          context: context,
          builder: (context) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final code in codes)
                  ListTile(
                    title: Text(code),
                    selected: code == current,
                    onTap: () => Navigator.of(context).pop(code),
                  ),
              ],
            ),
          ),
        );
        if (chosen == null || chosen == current) return;
        await ref.read(currencyCodeProvider.notifier).set(chosen);
      },
    );
  }
}
```

Place it in `settings_screen.dart` under a `SectionHeader(title: l.settingsTasks)` above `const CelebrationSettingsSection()`.

- [ ] **Step 6: Strings**

`app_en.arb`: `"settingsTasks": "Tasks"`, `"settingsCurrency": "Currency"`.
`app_de.arb`: `"settingsTasks": "Aufgaben"`, `"settingsCurrency": "Währung"`.
`app_it.arb`: `"settingsTasks": "Attività"`, `"settingsCurrency": "Valuta"`.

Run `cd app && flutter gen-l10n`.

- [ ] **Step 7: Run and commit**

```bash
cd app && flutter test test/features/settings/
git add app/lib app/test/features/settings/currency_tile_test.dart
git commit -m "$(cat <<'EOF'
feat(app): choose the currency amounts are written in

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01JK6GttYNgLykt2Ps5g5g6z
EOF
)"
```

---

### Task 6: The section on the task page

**Files:**
- Create: `app/lib/features/tasks/ui/task_work_section.dart`
- Modify: `app/lib/features/tasks/ui/task_detail_screen.dart`, `app/lib/l10n/*.arb`
- Test: `app/test/features/tasks/task_work_section_test.dart`

**Interfaces:**
- Consumes: `parseMinutes`, `parseMinorUnits`, `formatMinutes`, `formatMoney` (Task 3); `currencyCodeProvider` (Task 5); `Task.solution`, `Task.timeSpentMinutes`, `Task.costMinor` (Task 1).

- [ ] **Step 1: Write the failing tests**

Create `app/test/features/tasks/task_work_section_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_app.dart';

void main() {
  testWidgets('the section stays out of the way until it holds something', (
    tester,
  ) async {
    final harness = await pumpApp(tester, initialLocation: '/tasks/t1');
    await harness.seedList('l1', 'Home');
    await harness.seedTask('t1', 'l1', title: 'Fix the tap');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('task-solution')), findsNothing);

    await tester.tap(find.byKey(const Key('task-work-toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('task-solution')), findsOneWidget);
  });

  testWidgets('what is typed is stored as minutes and minor units', (
    tester,
  ) async {
    final harness = await pumpApp(tester, initialLocation: '/tasks/t1');
    await harness.seedList('l1', 'Home');
    await harness.seedTask('t1', 'l1', title: 'Fix the tap');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('task-work-toggle')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('task-solution')),
      'New washer, 12 mm',
    );
    await tester.enterText(find.byKey(const Key('task-time-spent')), '1h 30');
    await tester.enterText(find.byKey(const Key('task-cost')), '12.50');
    await tester.tap(find.text('Fix the tap'));
    await tester.pumpAndSettle();

    final task = await harness.db.taskById('t1');
    expect(task!.solution, 'New washer, 12 mm');
    expect(task.timeSpentMinutes, 90);
    expect(task.costMinor, 1250);
  });

  testWidgets('a time it cannot read leaves the stored one alone', (
    tester,
  ) async {
    final harness = await pumpApp(tester, initialLocation: '/tasks/t1');
    await harness.seedList('l1', 'Home');
    await harness.seedTask('t1', 'l1', title: 'Fix the tap');
    await harness.db.upsertTask(
      (await harness.db.taskById('t1'))!.copyWith(timeSpentMinutes: 45),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('task-time-spent')), 'a while');
    await tester.tap(find.text('Fix the tap'));
    await tester.pumpAndSettle();

    expect((await harness.db.taskById('t1'))!.timeSpentMinutes, 45);
  });
}
```

If `pump_app.dart` has no `seedTask` helper, add one beside the existing seeds, in their style.

- [ ] **Step 2: Run them to make sure they fail**

Run: `cd app && flutter test test/features/tasks/task_work_section_test.dart`
Expected: FAIL — no widget with key `task-work-toggle`.

- [ ] **Step 3: Write the section**

Create `app/lib/features/tasks/ui/task_work_section.dart`. Read `TaskPrioritySection` in `app/lib/features/tasks/ui/task_detail_sections.dart` first — this takes the same `task` + `save` pair it does.

```dart
class TaskWorkSection extends ConsumerStatefulWidget {
  const TaskWorkSection({required this.task, required this.save, super.key});

  final Task task;
  final Future<void> Function(Task) save;

  @override
  ConsumerState<TaskWorkSection> createState() => _TaskWorkSectionState();
}

class _TaskWorkSectionState extends ConsumerState<TaskWorkSection> {
  final _solution = TextEditingController();
  final _time = TextEditingController();
  final _cost = TextEditingController();
  final _solutionFocus = FocusNode();
  final _timeFocus = FocusNode();
  final _costFocus = FocusNode();
  bool? _expanded;

  bool get _hasAny =>
      widget.task.solution.isNotEmpty ||
      widget.task.timeSpentMinutes != null ||
      widget.task.costMinor != null;

  @override
  void initState() {
    super.initState();
    for (final focus in [_solutionFocus, _timeFocus, _costFocus]) {
      focus.addListener(_saveIfUnfocused);
    }
  }

  @override
  void dispose() {
    for (final c in [_solution, _time, _cost]) {
      c.dispose();
    }
    for (final f in [_solutionFocus, _timeFocus, _costFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  /// Never refills a field that has focus: an arriving sync would
  /// otherwise move the cursor out from under whoever is typing.
  void _fill(Task task, String locale) {
    if (!_solutionFocus.hasFocus && _solution.text != task.solution) {
      _solution.text = task.solution;
    }
    final minutes = task.timeSpentMinutes;
    if (!_timeFocus.hasFocus) {
      final shown = minutes == null ? '' : '$minutes';
      if (_time.text != shown) _time.text = shown;
    }
    final cost = task.costMinor;
    if (!_costFocus.hasFocus) {
      final shown = cost == null ? '' : (cost / 100).toStringAsFixed(2);
      if (_cost.text != shown) _cost.text = shown;
    }
  }

  void _saveIfUnfocused() {
    if (_solutionFocus.hasFocus || _timeFocus.hasFocus || _costFocus.hasFocus) {
      return;
    }
    unawaited(_save());
  }

  Future<void> _save() async {
    final task = widget.task;
    final locale = Localizations.localeOf(context).toLanguageTag();
    // An unreadable time or amount leaves what is stored alone. Writing
    // null there would turn a slip into "took no time", which is a real
    // answer somebody may have meant to record.
    final minutes = _time.text.trim().isEmpty
        ? null
        : parseMinutes(_time.text) ?? task.timeSpentMinutes;
    final cost = _cost.text.trim().isEmpty
        ? null
        : parseMinorUnits(_cost.text, locale: locale) ?? task.costMinor;
    final updated = task.copyWith(
      solution: _solution.text,
      timeSpentMinutes: minutes,
      costMinor: cost,
    );
    if (updated == task) return;
    await widget.save(updated);
  }
  // build(): a header row keyed 'task-work-toggle' showing l.tasksWork and,
  // when collapsed and _hasAny, a summary of formatMinutes(...) and
  // formatMoney(..., currency: ref.watch(currencyCodeProvider), locale: ...)
  // joined by ' · '; then, when (_expanded ?? _hasAny), the three fields
  // keyed 'task-solution' (maxLines: null, minLines: 2), 'task-time-spent'
  // and 'task-cost'.
}
```

Two details the skeleton leaves to you, both load-bearing: `copyWith` with a null `timeSpentMinutes` may not clear the field on a freezed class — if it does not, build the updated task with the full constructor, the same way Task 4 does for the repeat reset. And `_expanded` is nullable so that "never touched" falls back to `_hasAny` while an explicit tap wins.

Place it in `task_detail_screen.dart` after `TaskPrioritySection`:

```dart
            const SizedBox(height: 20),
            TaskWorkSection(task: task, save: _save),
```

- [ ] **Step 4: Strings**

`app_en.arb`: `"tasksWork": "What it took"`, `"tasksSolutionHint": "How it was solved"`, `"tasksTimeSpentHint": "Time spent"`, `"tasksCostHint": "Cost"`, `"tasksHours": "h"`, `"tasksMinutes": "min"`.
`app_de.arb`: `"tasksWork": "Was es gekostet hat"`, `"tasksSolutionHint": "Wie es gelöst wurde"`, `"tasksTimeSpentHint": "Aufgewendete Zeit"`, `"tasksCostHint": "Kosten"`, `"tasksHours": "Std."`, `"tasksMinutes": "Min."`.
`app_it.arb`: `"tasksWork": "Quanto è costata"`, `"tasksSolutionHint": "Come è stata risolta"`, `"tasksTimeSpentHint": "Tempo impiegato"`, `"tasksCostHint": "Costo"`, `"tasksHours": "h"`, `"tasksMinutes": "min"`.

Run `cd app && flutter gen-l10n`.

- [ ] **Step 5: Run and commit**

```bash
cd app && flutter test test/features/tasks/
git add app/lib app/test/features/tasks/task_work_section_test.dart app/test/support/pump_app.dart
git commit -m "$(cat <<'EOF'
feat(app): record what a task took, on the task page

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01JK6GttYNgLykt2Ps5g5g6z
EOF
)"
```

---

### Task 7: The export, the docs, and the full check

**Files:**
- Test: `app/test/features/settings/data_export_test.dart`
- Modify: `README.md`, `CHANGELOG.md`

- [ ] **Step 1: Write the failing export test**

Append to `app/test/features/settings/data_export_test.dart`:

```dart
  test('the export carries what a task took', () async {
    await seed(db);
    final id = await taskId(db, 'Report');
    await db.upsertTask(
      (await db.taskById(id))!.copyWith(
        solution: 'New washer, 12 mm',
        timeSpentMinutes: 90,
        costMinor: 1250,
      ),
    );

    final bytes = (await DataExport(db, testClock('a'), store).export(
      now: testNow,
    )).bytes;

    final fresh = testDatabase();
    await DataExport(fresh, testClock('b'), MemoryPhotoStore()).import(bytes);
    final restored = (await fresh.select(fresh.tasks).get())
        .firstWhere((t) => t.title == 'Report');

    expect(restored.solution, 'New washer, 12 mm');
    expect(restored.timeSpentMinutes, 90);
    expect(restored.costMinor, 1250);
    await fresh.close();
  });
```

Match the helper names to what the file actually has — read it first; `seed`, `taskId`, `testClock`, `MemoryPhotoStore` and `testDatabase` all exist there already.

- [ ] **Step 2: Run it**

Run: `cd app && flutter test test/features/settings/data_export_test.dart`
Expected: PASS without any production change — the export writes `Task.toJson`, so the fields ride along. If it fails, the export is filtering fields somewhere and that is a real finding: report it rather than patching the test.

- [ ] **Step 3: README and CHANGELOG**

README: a short paragraph in the tasks material saying a task can record how it was solved, how long it took and what it cost; that the three stay out of the way until one is filled; that the currency is a per-device setting; and that an app from before this drops the three if it edits such a task.

CHANGELOG: add to the existing `## Unreleased` section (do not create a second one):

```markdown
- A task can record how it was solved, how long it took and what it cost.
  The three stay out of the way until one is filled in.
```

- [ ] **Step 4: The full local CI sequence**

```bash
export PATH="$HOME/fvm/versions/3.47.2/bin:$PATH"
tool/pub_get.sh
(cd app && flutter gen-l10n)
(cd packages/nemo_core && dart run build_runner build --delete-conflicting-outputs)
(cd server && dart run build_runner build --delete-conflicting-outputs)
(cd app && dart run build_runner build --delete-conflicting-outputs)
(cd server && dart run drift_dev schema dump lib/src/db/server_database.dart drift_schemas/)
(cd server && dart run drift_dev schema generate drift_schemas/ test/generated/)
(cd app && dart run drift_dev schema dump lib/core/db/app_database.dart drift_schemas/)
(cd app && dart run drift_dev schema generate drift_schemas/ test/generated/)
git diff --quiet || { echo "generated files are stale"; git diff --name-only; }
dart format --output=none --set-exit-if-changed \
  packages/nemo_core/lib packages/nemo_core/test \
  server/lib server/bin server/test \
  app/lib app/test tool
tool/check_icons.sh
flutter analyze
(cd packages/nemo_core && dart test)
(cd server && dart test)
(cd app && flutter test --concurrency=2 --exclude-tags design)
(cd app && TZ=Europe/Berlin flutter test --tags dst --concurrency=2)
```

Expected: every command exits 0 and `git diff` is empty. Run the suites one at a time.

- [ ] **Step 5: Coverage floors**

```bash
(cd packages/nemo_core && dart test --coverage=coverage && \
  dart run coverage:format_coverage --lcov --in=coverage \
  --out=coverage/lcov.info --report-on=lib --base-directory=. && \
  dart run ../../tool/check_coverage.dart 90)
(cd server && dart test --coverage=coverage && \
  dart run coverage:format_coverage --lcov --in=coverage \
  --out=coverage/lcov.info --report-on=lib --base-directory=. && \
  dart run ../tool/check_coverage.dart 85)
(cd app && flutter test --coverage --exclude-tags design --concurrency=2 && \
  dart run ../tool/check_coverage.dart 80)
```

A floor that fails means a path in the new code has no test — add the test, never lower the floor.

- [ ] **Step 6: Commit**

```bash
git add README.md CHANGELOG.md app/test/features/settings/data_export_test.dart
git commit -m "$(cat <<'EOF'
docs: describe what a task took

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01JK6GttYNgLykt2Ps5g5g6z
EOF
)"
```

---

## Notes for the reviewer

Three places where this goes wrong quietly:

1. **The repeat reset.** Without it, a monthly task carries last month's solution, minutes and cost into every future occurrence, and nobody notices until a year of identical entries. Covered in Task 4.
2. **A parser returning zero instead of null.** `parseMinutes('a while')` must not store 0 — that silently overwrites a real recorded time with "took no time". Covered in Task 3 and again at the widget level in Task 6.
3. **The nullable `copyWith`.** freezed's generated `copyWith` cannot always set a nullable field back to null; if the repeat reset silently keeps the old value instead of clearing it, Task 4's test is what catches it.
