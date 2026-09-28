# Reminder Offsets and Actions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A task can have several reminders picked from presets relative to its due time, and every reminder notification carries Done, Snooze 10 min and Snooze 1 h buttons that work without opening the app.

**Architecture:** A synced `reminders: List<int>` (minutes before due) joins `Task`, with the old `remind` flag kept as its master switch for older apps. A pure `reminderFireAt` turns an offset into an instant (all-day tasks anchor at the daily list's time). `AndroidReminderScheduler` schedules one notification per offset with action buttons and a `/tasks/<id>` payload. A shared `handleReminderAction` runs Done/Snooze, called from the foreground callback or from a top-level background entry point that opens the (now isolate-shared) database itself.

**Tech Stack:** Dart 3.13, Flutter 3.47.2 (fvm), drift + drift_flutter, freezed + json_serializable, Riverpod 3, flutter_local_notifications 22.3.

**Spec:** `docs/superpowers/specs/2026-09-28-reminder-offsets-and-actions-design.md`. Requires the daily list plan (`2026-09-28-daily-list.md`) merged first: this plan uses its `NotificationsApi` shape (`channelId`, `lines`, `payload`, `onTap`, `launchPayload`), `KvKeys.dailyListMinutes`, `notificationRouteProvider` and `dailyListRefresherProvider`.

## Global Constraints

- **Model:** `Task.reminders` (`List<int>`, JSON key `reminders`, default `[]`), minutes before due; `0` = at due time. `Task.effectiveReminders` = `remind ? (reminders.isEmpty ? [0] : reminders) : []`. Every writer goes through `Task.withReminders(list)`, which sets `reminders` (sorted, de-duplicated) and `remind: list.isNotEmpty`.
- **Presets:** timed `[0, 5, 15, 30, 60, 120, 1440, 2880, 10080]`; all-day `[0, 1440, 2880, 10080]`. No custom offsets.
- **All-day anchor:** `KvKeys.dailyListMinutes` (default 480) on the local due date, minus `offset ~/ 1440` days; sub-day offsets on an all-day task count as `0`; duplicate fire times post once.
- **Ids:** `notificationId(taskId, offset) = '$taskId:$offset'.hashCode & 0x7fffffff`; `snoozeId(taskId) = '$taskId:snooze'.hashCode & 0x7fffffff`; `legacyNotificationId(taskId) = taskId.hashCode & 0x7fffffff` is still cancelled on every sync so reminders scheduled by 0.14 do not fire twice. Daily list ids `-1..-7` stay untouched.
- **Payload:** `Routes.task(id)` (`/tasks/<id>`); action ids `done`, `snooze10`, `snooze60`, all `showsUserInterface: false`, `cancelNotification: true`.
- **Snooze** is device-local and never synced; a new snooze replaces the old; any `sync(task)` cancels it.
- **Background Done** = `TasksRepository.setDone(id, done: true)`: HLC-stamped, repeats roll on, no celebration.
- Schemas: app 5 → 6, server 6 → 7; `remind = 1` rows migrate to `reminders = '[0]'`, others `'[]'`.
- Web: unchanged (no reminders).
- Toolchain: every shell starts with `export PATH="$HOME/fvm/versions/3.47.2/bin:$PATH"` (the pre-commit hook runs the generators and fails without it). **Never background a test run**; foreground, 600 s timeout, one test process at a time; the app suite runs `flutter test --concurrency=2`. Core: `cd packages/nemo_core && dart test`; server: `cd server && dart test`.
- `flutter analyze` must exit 0; capture it as `flutter analyze > /tmp/analyze.txt 2>&1; echo "EXIT=$?"`.
- Row classes live in `packages/nemo_core`; the tasks table is declared twice (`app/lib/core/db/sync_tables.dart`, `server/lib/src/db/sync_tables.dart`) and both must match `Task`'s constructor. Generated code and drift schema snapshots are committed.
- `very_good_analysis`: required named parameters before optional ones.
- Every user-visible string in en/de/it arb files, then `cd app && flutter gen-l10n`.
- Append tests; never rewrite a test file wholesale. `dart format` `lib` and `test` of every package touched. Stage by explicit path after `git status --short`.
- Conventional Commits ending with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Branch `feat/reminder-offsets` off `main` after the daily list is merged.

## Review Focus

- Upgrading from 0.14 with an at-due reminder already scheduled must not produce two notifications -- Task 4 test "cancels the legacy id".
- A task switched from timed to all-day keeps offsets like `15`: it must post one morning reminder, not two -- Task 3 test "sub-day offsets on an all-day task collapse to the morning" and Task 4 "duplicate fire times post once".
- Done tapped on a task that was already ticked off (or deleted) on another device and synced: nothing happens, no crash, no resurrected row -- Task 5 test "done on a done or missing task does nothing".
- Done on a repeating task from the notification must schedule the next occurrence's reminders, since the user never opens the app -- Task 5 test "done rolls a repeating task on with its reminders".
- Changing the daily list time must move already-scheduled all-day reminders -- Task 6 test "changing the daily list time re-syncs reminders".

---

### Task 1: `reminders` on `Task`

**Files:**
- Modify: `packages/nemo_core/lib/src/model/task.dart` (+ regenerated `task.freezed.dart`, `task.g.dart`)
- Modify: `packages/nemo_core/lib/src/converters.dart`
- Test: `packages/nemo_core/test/model_test.dart`

**Interfaces:**
- Produces: `Task.reminders` (`List<int>`), `Task.effectiveReminders` (`List<int>`), `Task.withReminders(Iterable<int>) → Task`, `IntListConverter` (`TypeConverter<List<int>, String>`, JSON array text).

- [ ] **Step 1: Branch**

```bash
git switch -c feat/reminder-offsets
export PATH="$HOME/fvm/versions/3.47.2/bin:$PATH"
```

- [ ] **Step 2: Failing tests** -- append to `packages/nemo_core/test/model_test.dart`:

```dart
  group('reminders', () {
    const base = Task(
      id: 't1',
      listId: 'l1',
      title: 'Dentist',
      sortKey: 'V',
      updatedAt: '0000000000001-0000-n',
    );

    test('round-trip through JSON', () {
      final task = base.withReminders([1440, 0]);
      final json =
          jsonDecode(jsonEncode(task.toJson())) as Map<String, dynamic>;
      expect(json['reminders'], [0, 1440]);
      expect(json['remind'], isTrue);
      expect(Task.fromJson(json), task);
    });

    test('a task from before reminders reads with none', () {
      final task = Task.fromJson({
        'id': 't1',
        'list_id': 'l1',
        'title': 'Dentist',
        'sort_key': 'V',
        'updated_at': '0000000000001-0000-n',
      });
      expect(task.reminders, isEmpty);
      expect(task.effectiveReminders, isEmpty);
    });

    test('remind alone means at due time', () {
      expect(base.copyWith(remind: true).effectiveReminders, [0]);
    });

    test('remind off silences any offsets', () {
      expect(
        base.copyWith(reminders: [15]).effectiveReminders,
        isEmpty,
      );
    });

    test('withReminders sorts, de-duplicates and sets remind', () {
      final task = base.withReminders([60, 0, 60]);
      expect(task.reminders, [0, 60]);
      expect(task.remind, isTrue);
      final none = task.withReminders([]);
      expect(none.reminders, isEmpty);
      expect(none.remind, isFalse);
    });
  });

  test('IntListConverter stores a JSON array', () {
    const c = IntListConverter();
    expect(c.toSql([0, 15]), '[0,15]');
    expect(c.fromSql('[0,15]'), [0, 15]);
  });
```

(If `IntListConverter` is not exported from `package:nemo_core/nemo_core.dart` the way `StringListConverter` is, export it next to it.)

- [ ] **Step 3: Run** `cd packages/nemo_core && dart test test/model_test.dart` -- FAIL (`reminders` undefined).

- [ ] **Step 4: Implement** -- `task.dart`, after `@Default(false) bool remind,`:

```dart
    /// Minutes before the due time to remind at; `0` is the due time
    /// itself. Only meaningful while [remind] is on: older apps know only
    /// that flag, so it stays the switch and this list says when.
    @Default(<int>[]) List<int> reminders,
```

and in the body, after `repeatRule`:

```dart
  /// When to remind, whatever wrote the row: an older app's `remind` with
  /// no offsets means at the due time.
  List<int> get effectiveReminders {
    if (!remind) return const [];
    return reminders.isEmpty ? const [0] : reminders;
  }

  /// This task reminding at [offsets], and only those. The one way to set
  /// reminders, so [remind] never disagrees with them.
  Task withReminders(Iterable<int> offsets) {
    final sorted = offsets.toSet().toList()..sort();
    return copyWith(reminders: sorted, remind: sorted.isNotEmpty);
  }
```

`converters.dart`:

```dart
/// Stores a list of integers as a JSON array in a text column; the
/// `reminders` column's twin of [StringListConverter].
class IntListConverter extends TypeConverter<List<int>, String> {
  const IntListConverter();

  @override
  List<int> fromSql(String fromDb) =>
      (jsonDecode(fromDb) as List<dynamic>).cast<int>();

  @override
  String toSql(List<int> value) => jsonEncode(value);
}
```

- [ ] **Step 5: Generate and run**

```bash
cd packages/nemo_core && dart run build_runner build --delete-conflicting-outputs && dart test
```

Expected: PASS, whole package.

- [ ] **Step 6: Commit**

```bash
git add packages/nemo_core/lib packages/nemo_core/test/model_test.dart
git commit -m "feat(core): let a task remind at several offsets before it is due

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Both schemas

**Files:**
- Modify: `app/lib/core/db/sync_tables.dart`, `server/lib/src/db/sync_tables.dart`
- Modify: `app/lib/core/db/app_database.dart` (schema 6), `server/lib/src/db/server_database.dart` (schema 7)
- Create: `app/drift_schemas/drift_schema_v6.json`, `server/drift_schemas/drift_schema_v7.json`, regenerated `test/generated/` helpers on both sides
- Test: `app/test/core/db/migration_test.dart`, `server/test/migration_test.dart`

**Interfaces:**
- Consumes: `IntListConverter`, `Task.reminders` (Task 1).
- Produces: `tasks.reminders` text column (default `'[]'`) on both sides.

- [ ] **Step 1: Failing migration test** -- append to `app/test/core/db/migration_test.dart`:

```dart
  test('v6 turns a remind flag into an at-due reminder', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(5);
    schema.rawDatabase
      ..execute(
        "insert into lists (id, name, sort_key, updated_at) "
        "values ('l1', 'Inbox', 'V', '0000000000001-0000-n')",
      )
      ..execute(
        "insert into tasks (id, list_id, title, sort_key, updated_at, remind, tags) "
        "values ('a', 'l1', 'On', 'V', '0000000000001-0000-n', 1, '[]'), "
        "('b', 'l1', 'Off', 'V', '0000000000001-0000-n', 0, '[]')",
      );
    final db = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(db, 6);
    expect((await db.taskById('a'))!.reminders, [0]);
    expect((await db.taskById('b'))!.reminders, isEmpty);
    await db.close();
  });
```

If the v5 `lists` table has more required columns, add them to the insert (read them from `app/drift_schemas/drift_schema_v5.json`). Extend the existing "every earlier version" loop to `[1, 2, 3, 4, 5]` with target `6`, and the index test's target to `6`. In `server/test/migration_test.dart` make the same two edits (loop `[1, 2, 3, 4, 5, 6]`, target `7`) and append the server twin of the test above using `ServerDatabase(schema.newConnection())`, `schemaAt(6)`, `migrateAndValidate(db, 7)`, reading the rows back with a plain `select` on `db.tasks` if `taskById` does not exist there.

- [ ] **Step 2: Run** `cd app && flutter test test/core/db/migration_test.dart` -- FAIL (no schema version 6).

- [ ] **Step 3: Columns** -- in both `sync_tables.dart`, after `remind`:

```dart
  TextColumn get reminders => text()
      .map(const IntListConverter())
      .withDefault(const Constant('[]'))();
```

- [ ] **Step 4: Migrations** -- `app_database.dart`: `schemaVersion => 6`, and at the end of `onUpgrade`:

```dart
      if (from < 6) {
        await m.addColumn(tasks, tasks.reminders);
        // The old flag meant "at the due time".
        await customStatement(
          "update tasks set reminders = '[0]' where remind = 1",
        );
      }
```

`server_database.dart`: `schemaVersion => 7`, the identical block guarded `if (from < 7)`.

- [ ] **Step 5: Regenerate and dump**

```bash
(cd app && dart run build_runner build --delete-conflicting-outputs)
(cd server && dart run build_runner build --delete-conflicting-outputs)
(cd app && dart run drift_dev schema dump lib/core/db/app_database.dart drift_schemas/ && dart run drift_dev schema generate drift_schemas/ test/generated/)
(cd server && dart run drift_dev schema dump lib/src/db/server_database.dart drift_schemas/ && dart run drift_dev schema generate drift_schemas/ test/generated/)
```

- [ ] **Step 6: Run** both migration suites, then the server suite whole (sync round-trips every task column):

```bash
(cd app && flutter test test/core/db/migration_test.dart)
(cd server && dart test)
```

Expected: PASS.

- [ ] **Step 7: Sync keeps offsets** -- append to the server's sync test (find it with `grep -rln "solution" server/test`), using that file's push/pull helpers the way its `solution` round-trip test does: push a task with `reminders: [0, 1440], remind: true`, pull it from a second client, expect the same `reminders`. Run `cd server && dart test` -- PASS.

- [ ] **Step 8: Commit**

```bash
git add app/lib/core/db app/drift_schemas app/test/core/db app/test/generated server/lib server/drift_schemas server/test
git commit -m "feat(db): store reminder offsets in both schemas

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Presets and fire times

**Files:**
- Create: `app/lib/core/notifications/reminder_presets.dart`
- Test: `app/test/core/notifications/reminder_presets_test.dart`

**Interfaces:**
- Consumes: `Task.effectiveReminders` (Task 1).
- Produces:
  ```dart
  const timedPresets = [0, 5, 15, 30, 60, 120, 1440, 2880, 10080];
  const allDayPresets = [0, 1440, 2880, 10080];
  DateTime? reminderFireAt(Task task, int offset, {required int anchorMinutes});
  /// Distinct future fire times for [task], each with the offset that produced it first.
  List<({int offset, DateTime at})> reminderSchedule(Task task, {required DateTime now, required int anchorMinutes});
  ```

- [ ] **Step 1: Failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/notifications/reminder_presets.dart';
import 'package:nemo_core/nemo_core.dart';

void main() {
  Task task({required DateTime due, bool hasTime = true, List<int> at = const [0]}) =>
      Task(
        id: 't',
        listId: 'l',
        title: 'Dentist',
        sortKey: 'V',
        updatedAt: '0000000000001-0000-n',
        dueAt: due.millisecondsSinceEpoch,
        dueHasTime: hasTime,
      ).withReminders(at);

  test('timed offsets count back from the due time', () {
    final t = task(due: DateTime(2026, 10, 2, 14, 30));
    expect(
      reminderFireAt(t, 15, anchorMinutes: 480),
      DateTime(2026, 10, 2, 14, 15),
    );
    expect(
      reminderFireAt(t, 1440, anchorMinutes: 480),
      DateTime(2026, 10, 1, 14, 30),
    );
  });

  test('all-day tasks fire at the anchor, whole days back', () {
    final t = task(due: DateTime(2026, 10, 2), hasTime: false);
    expect(reminderFireAt(t, 0, anchorMinutes: 480), DateTime(2026, 10, 2, 8));
    expect(
      reminderFireAt(t, 2880, anchorMinutes: 450),
      DateTime(2026, 9, 30, 7, 30),
    );
  });

  test('sub-day offsets on an all-day task collapse to the morning', () {
    final t = task(due: DateTime(2026, 10, 2), hasTime: false);
    expect(reminderFireAt(t, 15, anchorMinutes: 480), DateTime(2026, 10, 2, 8));
  });

  test('all-day keeps the anchor across a DST change', () {
    // 25 Oct 2026 the EU clocks go back; a week before must still be 08:00.
    final t = task(due: DateTime(2026, 10, 28), hasTime: false);
    final at = reminderFireAt(t, 10080, anchorMinutes: 480)!;
    expect((at.day, at.hour, at.minute), (21, 8, 0));
  });

  test('no due date, no fire time', () {
    const t = Task(
      id: 't',
      listId: 'l',
      title: 'x',
      sortKey: 'V',
      updatedAt: '0000000000001-0000-n',
    );
    expect(reminderFireAt(t, 0, anchorMinutes: 480), isNull);
  });

  test('schedule keeps future, distinct fire times only', () {
    final t = task(
      due: DateTime(2026, 10, 2),
      hasTime: false,
      at: [0, 15, 1440, 10080],
    );
    final now = DateTime(2026, 9, 28, 9);
    final schedule = reminderSchedule(t, now: now, anchorMinutes: 480);
    // 10080 (25 Sep) is past; 0 and 15 both mean 2 Oct 08:00.
    expect(schedule.map((s) => s.offset), [0, 1440]);
    expect(schedule.first.at, DateTime(2026, 10, 2, 8));
  });
}
```

- [ ] **Step 2: Run** `cd app && flutter test test/core/notifications/reminder_presets_test.dart` -- FAIL (file missing).

- [ ] **Step 3: Implement** `reminder_presets.dart`:

```dart
import 'package:nemo_core/nemo_core.dart';

/// Offsets offered for a task with a time: at due, 5, 15, 30 min, 1 h,
/// 2 h, 1 day, 2 days and a week before.
const timedPresets = [0, 5, 15, 30, 60, 120, 1440, 2880, 10080];

/// Offsets offered for an all-day task: that morning, 1 day, 2 days and a
/// week before.
const allDayPresets = [0, 1440, 2880, 10080];

/// When the reminder [offset] minutes before [task]'s due fires, or null
/// without a due date.
///
/// An all-day task reminds at [anchorMinutes] after local midnight (the
/// daily list's time) on its day, or whole days before it; an offset
/// shorter than a day, left over from when it had a time, means that
/// morning. Built from calendar fields, so a daylight-saving change keeps
/// the wall-clock time.
DateTime? reminderFireAt(
  Task task,
  int offset, {
  required int anchorMinutes,
}) {
  final dueAt = task.dueAt;
  if (dueAt == null) return null;
  final due = DateTime.fromMillisecondsSinceEpoch(dueAt);
  if (task.dueHasTime) return due.subtract(Duration(minutes: offset));
  return DateTime(
    due.year,
    due.month,
    due.day - offset ~/ 1440,
    anchorMinutes ~/ 60,
    anchorMinutes % 60,
  );
}

/// The reminders [task] should have scheduled after [now]: one per distinct
/// fire time, keeping the smallest offset that lands on it.
List<({int offset, DateTime at})> reminderSchedule(
  Task task, {
  required DateTime now,
  required int anchorMinutes,
}) {
  final seen = <DateTime>{};
  return [
    for (final offset in task.effectiveReminders)
      if (reminderFireAt(task, offset, anchorMinutes: anchorMinutes)
          case final at?
          when at.isAfter(now) && seen.add(at))
        (offset: offset, at: at),
  ];
}
```

(`effectiveReminders` is sorted ascending by `withReminders`, so the first offset on a fire time is the smallest.)

- [ ] **Step 4: Run** the test -- PASS; `flutter analyze` exit 0.

- [ ] **Step 5: Commit**

```bash
git add app/lib/core/notifications/reminder_presets.dart app/test/core/notifications/reminder_presets_test.dart
git commit -m "feat(app): work out when each reminder offset fires

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: The scheduler posts offsets with buttons, and snoozes

**Files:**
- Modify: `app/lib/core/notifications/notifications_api.dart`
- Modify: `app/lib/core/notifications/reminder_scheduler.dart` (`wantsReminder`)
- Modify: `app/lib/core/notifications/android_reminder_scheduler.dart`
- Modify: `app/test/support/fake_notifications.dart`, `app/test/core/notifications/notifications_api_test.dart`, `app/test/core/notifications/android_reminder_scheduler_test.dart`
- Modify: `app/lib/main.dart` (build the scheduler with `reminderStrings(l)` and the anchor)
- Modify: `app/lib/core/db/kv_store.dart` (`readDailyListMinutes`), `app/lib/core/providers.dart` (use it in `AppBootstrap.load`)
- Modify: `app/lib/l10n/app_en.arb`, `app_de.arb`, `app_it.arb`

**Interfaces:**
- Consumes: `reminderSchedule` (Task 3), `NotificationsApi` from the daily list plan.
- Produces:
  ```dart
  class NotificationAction { const NotificationAction(this.id, this.label); final String id; final String label; }
  // NotificationsApi.scheduleAt gains: List<NotificationAction> actions = const []
  // NotificationsApi.initialize gains: void Function(String actionId, String? payload)? onAction,
  //                                    DidReceiveBackgroundNotificationResponseCallback? onBackground
  class ReminderStrings {
    const ReminderStrings({required String channelName, required String channelDescription,
      required String dueNow, required String dueToday, required String Function(int) dueInMinutes,
      required String Function(int) dueInHours, required String Function(int) dueInDays,
      required String snoozed, required String done, required String snooze10, required String snooze60});
  }
  class AndroidReminderScheduler implements ReminderScheduler {
    AndroidReminderScheduler(NotificationsApi api, {required ReminderStrings strings,
      required Future<int> Function() anchorMinutes, DateTime Function()? now});
    static int notificationId(String taskId, int offset);
    static int snoozeId(String taskId);
    static int legacyNotificationId(String taskId);
    Future<void> snooze(Task task, Duration by);
  }
  const reminderActionDone = 'done', reminderActionSnooze10 = 'snooze10', reminderActionSnooze60 = 'snooze60';
  String? taskIdFromPayload(String? payload); // '/tasks/<id>' → id
  ```

- [ ] **Step 1: Failing api test** -- append to `notifications_api_test.dart`:

```dart
  test('schedules action buttons that do not open the app', () async {
    final notifications = api();
    await notifications.initialize();
    await notifications.scheduleAt(
      id: 9,
      title: 'Dentist',
      body: 'Due now',
      epochMs: DateTime.utc(2099, 9, 7, 15).millisecondsSinceEpoch,
      channelName: 'Reminders',
      channelDescription: 'desc',
      payload: '/tasks/t1',
      actions: const [
        NotificationAction('done', 'Done'),
        NotificationAction('snooze10', 'Snooze 10 min'),
      ],
    );
    final args =
        calls.singleWhere((c) => c.method == 'zonedSchedule').arguments
            as Map<Object?, Object?>;
    final specifics = args['platformSpecifics']! as Map<Object?, Object?>;
    final actions = (specifics['actions']! as List<Object?>)
        .cast<Map<Object?, Object?>>();
    expect(actions.map((a) => a['id']), ['done', 'snooze10']);
    expect(actions.first['showsUserInterface'], isFalse);
    expect(actions.first['cancelNotification'], isTrue);
  });
```

- [ ] **Step 2: Failing scheduler tests** -- in `android_reminder_scheduler_test.dart`, replace the `setUp` construction and the old 'schedules open future reminders…' test body (the one that uses the removed `body:` parameter -- this is an update of that test, not a rewrite of the file) and append the rest:

```dart
  const strings = ReminderStrings(
    channelName: 'Reminders',
    channelDescription: 'desc',
    dueNow: 'Due now',
    dueToday: 'Due today',
    dueInMinutes: _min,
    dueInHours: _hours,
    dueInDays: _days,
    snoozed: 'Snoozed',
    done: 'Done',
    snooze10: 'Snooze 10 min',
    snooze60: 'Snooze 1 h',
  );
  // top level of the file:
  // String _min(int n) => 'Due in $n min';
  // String _hours(int n) => 'Due in $n h';
  // String _days(int n) => n == 1 ? 'Due tomorrow' : 'Due in $n days';

  setUp(() {
    api = FakeApi();
    scheduler = AndroidReminderScheduler(
      api,
      strings: strings,
      anchorMinutes: () async => 480,
      now: () => now,
    );
  });

  Task timed(List<int> at, {bool done = false, String? deletedAt}) => Task(
    id: 'task-1',
    listId: 'l',
    title: 'Dentist',
    sortKey: 'V',
    updatedAt: '0000000000001-0000-n',
    done: done,
    deletedAt: deletedAt,
    dueAt: DateTime(2026, 9, 8, 14).millisecondsSinceEpoch,
    dueHasTime: true,
  ).withReminders(at);

  int id(int offset) => AndroidReminderScheduler.notificationId('task-1', offset);

  test('one notification per future offset, with buttons and payload', () async {
    // now is 7 Sep 10:00; due 8 Sep 14:00; a week before is past.
    await scheduler.sync(timed([0, 60, 1440, 10080]));
    expect(api.scheduled.keys.toSet(), {id(0), id(60), id(1440)});
    expect(api.scheduled[id(0)]!.body, 'Due now');
    expect(api.scheduled[id(60)]!.body, 'Due in 1 h');
    expect(api.scheduled[id(1440)]!.body, 'Due tomorrow');
    expect(
      api.scheduled[id(60)]!.at,
      DateTime(2026, 9, 8, 13).millisecondsSinceEpoch,
    );
    expect(api.scheduled[id(0)]!.payload, '/tasks/task-1');
    expect(api.scheduled[id(0)]!.actions.map((a) => a.id), [
      reminderActionDone,
      reminderActionSnooze10,
      reminderActionSnooze60,
    ]);
  });

  test('ids are distinct per offset and never negative', () {
    final ids = {for (final o in timedPresets) id(o)};
    expect(ids, hasLength(timedPresets.length));
    expect(ids.every((i) => i >= 0), isTrue);
  });

  test('sync cancels every preset, the snooze and the legacy id', () async {
    await scheduler.sync(timed([0]));
    api.cancelled.clear();
    await scheduler.sync(timed([], done: true));
    expect(api.cancelled, containsAll([
      for (final o in timedPresets) id(o),
      AndroidReminderScheduler.snoozeId('task-1'),
      AndroidReminderScheduler.legacyNotificationId('task-1'),
    ]));
    expect(api.scheduled, isEmpty);
  });

  test('cancels the legacy id so an upgraded reminder does not fire twice',
      () async {
    await scheduler.sync(timed([0]));
    expect(
      api.cancelled,
      contains(AndroidReminderScheduler.legacyNotificationId('task-1')),
    );
  });

  test('done, deleted and undated tasks keep nothing', () async {
    await scheduler.sync(timed([0], done: true));
    await scheduler.sync(timed([0], deletedAt: 'x'));
    await scheduler.sync(timed([0]).copyWith(dueAt: null));
    expect(api.scheduled, isEmpty);
  });

  test('duplicate fire times post once', () async {
    final allDay = timed([0, 15]).copyWith(
      dueAt: DateTime(2026, 9, 9).millisecondsSinceEpoch,
      dueHasTime: false,
    );
    await scheduler.sync(allDay);
    expect(api.scheduled, hasLength(1));
    expect(api.scheduled.values.single.body, 'Due today');
    expect(
      api.scheduled.values.single.at,
      DateTime(2026, 9, 9, 8).millisecondsSinceEpoch,
    );
  });

  test('snooze posts again later and a second snooze replaces it', () async {
    final task = timed([0]);
    await scheduler.snooze(task, const Duration(minutes: 10));
    final snooze = AndroidReminderScheduler.snoozeId('task-1');
    expect(
      api.scheduled[snooze]!.at,
      now.add(const Duration(minutes: 10)).millisecondsSinceEpoch,
    );
    expect(api.scheduled[snooze]!.body, 'Snoozed');
    expect(api.scheduled[snooze]!.actions, hasLength(3));
    await scheduler.snooze(task, const Duration(hours: 1));
    expect(
      api.scheduled[snooze]!.at,
      now.add(const Duration(hours: 1)).millisecondsSinceEpoch,
    );
  });

  test('a later sync clears a snooze', () async {
    await scheduler.snooze(timed([0]), const Duration(minutes: 10));
    await scheduler.sync(timed([0], done: true));
    expect(
      api.scheduled.containsKey(AndroidReminderScheduler.snoozeId('task-1')),
      isFalse,
    );
  });

  test('payload parsing', () {
    expect(taskIdFromPayload('/tasks/abc'), 'abc');
    expect(taskIdFromPayload('/today'), isNull);
    expect(taskIdFromPayload(null), isNull);
  });
```

Update `FakeApi` in `test/support/fake_notifications.dart`: `scheduleAt` takes `List<NotificationAction> actions = const []` and records it (`actions: actions` in the record, typed `List<NotificationAction>`); `initialize` takes the two new optional callbacks and stores `onAction` in a public field `void Function(String, String?)? onAction`.

- [ ] **Step 3: Run** `cd app && flutter test --concurrency=2 test/core/notifications` -- fails to compile.

- [ ] **Step 4: Implement**

`notifications_api.dart` -- add:

```dart
/// A button on a notification; [id] comes back to the action handler.
class NotificationAction {
  const NotificationAction(this.id, this.label);
  final String id;
  final String label;
}
```

Interface changes:

```dart
  Future<void> initialize({
    void Function(String? payload)? onTap,
    // A button tapped while the app runs.
    void Function(String actionId, String? payload)? onAction,
    // A button tapped while it does not: a top-level function run in a
    // background isolate.
    DidReceiveBackgroundNotificationResponseCallback? onBackground,
  });
  Future<void> scheduleAt({
    // ...existing parameters...
    List<NotificationAction> actions = const [],
  });
```

`LocalNotificationsApi.initialize`:

```dart
    await _plugin.initialize(
      settings: /* unchanged */,
      onDidReceiveNotificationResponse: (response) {
        final action = response.actionId;
        if (action != null && action.isNotEmpty) {
          onAction?.call(action, response.payload);
        } else {
          onTap?.call(response.payload);
        }
      },
      onDidReceiveBackgroundNotificationResponse: onBackground,
    );
```

`AndroidNotificationDetails` in `scheduleAt` gains:

```dart
        actions: [
          for (final a in actions)
            AndroidNotificationAction(
              a.id,
              a.label,
              // Done and Snooze are the point of not opening the app.
              showsUserInterface: false,
              cancelNotification: true,
            ),
        ],
```

`reminder_scheduler.dart` -- `wantsReminder` uses the new field:

```dart
bool wantsReminder(Task task, DateTime now) =>
    task.effectiveReminders.isNotEmpty &&
    !task.done &&
    !task.isDeleted &&
    task.dueAt != null;
```

(Future-ness is now per offset, in `reminderSchedule`.)

`android_reminder_scheduler.dart` -- replace the class:

```dart
import 'package:nemo/core/notifications/notifications_api.dart';
import 'package:nemo/core/notifications/reminder_presets.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo_core/nemo_core.dart';

const reminderActionDone = 'done';
const reminderActionSnooze10 = 'snooze10';
const reminderActionSnooze60 = 'snooze60';

/// The task a reminder's payload (`Routes.task(id)`) points at.
String? taskIdFromPayload(String? payload) {
  const prefix = '/tasks/';
  if (payload == null || !payload.startsWith(prefix)) return null;
  final id = payload.substring(prefix.length);
  return id.isEmpty ? null : Uri.decodeComponent(id);
}

/// Reminder text, from the device locale like the channel's name.
class ReminderStrings {
  const ReminderStrings({
    required this.channelName,
    required this.channelDescription,
    required this.dueNow,
    required this.dueToday,
    required this.dueInMinutes,
    required this.dueInHours,
    required this.dueInDays,
    required this.snoozed,
    required this.done,
    required this.snooze10,
    required this.snooze60,
  });

  final String channelName;
  final String channelDescription;
  final String dueNow;
  final String dueToday;
  final String Function(int minutes) dueInMinutes;
  final String Function(int hours) dueInHours;
  final String Function(int days) dueInDays;
  final String snoozed;
  final String done;
  final String snooze10;
  final String snooze60;

  /// What a reminder [offset] minutes ahead of the due says.
  String body(int offset, {required bool allDay}) {
    if (offset >= 1440) return dueInDays(offset ~/ 1440);
    if (allDay) return dueToday;
    if (offset == 0) return dueNow;
    if (offset < 60) return dueInMinutes(offset);
    return dueInHours(offset ~/ 60);
  }

  List<NotificationAction> get actions => [
    NotificationAction(reminderActionDone, done),
    NotificationAction(reminderActionSnooze10, snooze10),
    NotificationAction(reminderActionSnooze60, snooze60),
  ];
}

/// Reminders as local notifications, one per offset before a task's due.
class AndroidReminderScheduler implements ReminderScheduler {
  AndroidReminderScheduler(
    this._api, {
    required this.strings,
    required this.anchorMinutes,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final NotificationsApi _api;
  final ReminderStrings strings;

  /// The daily list's time, where all-day tasks are reminded. Read on every
  /// sync, so a change applies to the next one.
  final Future<int> Function() anchorMinutes;
  final DateTime Function() _now;

  /// Stable non-negative id of one offset's notification for a task.
  static int notificationId(String taskId, int offset) =>
      '$taskId:$offset'.hashCode & 0x7fffffff;

  static int snoozeId(String taskId) =>
      '$taskId:snooze'.hashCode & 0x7fffffff;

  /// The one id 0.14 used per task. Cancelled on every sync so a reminder
  /// scheduled before the update never fires beside its replacement.
  static int legacyNotificationId(String taskId) =>
      taskId.hashCode & 0x7fffffff;

  @override
  Future<bool> ensurePermission() => _api.requestPermission();

  @override
  Future<void> sync(Task task) async {
    await cancel(task.id);
    if (!wantsReminder(task, _now())) return;
    final schedule = reminderSchedule(
      task,
      now: _now(),
      anchorMinutes: await anchorMinutes(),
    );
    for (final (:offset, :at) in schedule) {
      await _post(
        id: notificationId(task.id, offset),
        task: task,
        body: strings.body(offset, allDay: !task.dueHasTime),
        at: at,
      );
    }
  }

  /// Posts [task]'s reminder again after [by]; replaces an earlier snooze.
  Future<void> snooze(Task task, Duration by) => _post(
    id: snoozeId(task.id),
    task: task,
    body: strings.snoozed,
    at: _now().add(by),
  );

  @override
  Future<void> cancel(String taskId) async {
    // Every preset, whatever the task carries now: cheaper than
    // remembering what was scheduled, and right after any edit.
    for (final offset in timedPresets) {
      await _api.cancel(notificationId(taskId, offset));
    }
    await _api.cancel(snoozeId(taskId));
    await _api.cancel(legacyNotificationId(taskId));
  }

  Future<void> _post({
    required int id,
    required Task task,
    required String body,
    required DateTime at,
  }) => _api.scheduleAt(
    id: id,
    title: task.title,
    body: body,
    epochMs: at.millisecondsSinceEpoch,
    channelName: strings.channelName,
    channelDescription: strings.channelDescription,
    payload: '/tasks/${Uri.encodeComponent(task.id)}',
    actions: strings.actions,
  );
}
```

(`allDayPresets` is a subset of `timedPresets`, so cancelling the timed ones covers both.) Drop the old `body` field.

l10n -- `app_en.arb`, replacing `"remindersDueNow"`:

```json
  "remindDueNow": "Due now",
  "remindDueToday": "Due today",
  "remindDueInMinutes": "Due in {count} min",
  "@remindDueInMinutes": {"placeholders": {"count": {"type": "int"}}},
  "remindDueInHours": "{count, plural, =1{Due in 1 hour} other{Due in {count} hours}}",
  "@remindDueInHours": {"placeholders": {"count": {"type": "int"}}},
  "remindDueInDays": "{count, plural, =1{Due tomorrow} other{Due in {count} days}}",
  "@remindDueInDays": {"placeholders": {"count": {"type": "int"}}},
  "remindSnoozed": "Snoozed",
  "remindActionDone": "Done",
  "remindActionSnooze10": "Snooze 10 min",
  "remindActionSnooze60": "Snooze 1 h",
```

`app_de.arb`: `"Jetzt fällig"`, `"Heute fällig"`, `"Fällig in {count} Min."`, `"{count, plural, =1{Fällig in 1 Stunde} other{Fällig in {count} Stunden}}"`, `"{count, plural, =1{Morgen fällig} other{Fällig in {count} Tagen}}"`, `"Zurückgestellt"`, `"Erledigt"`, `"10 Min. später"`, `"1 Std. später"`.

`app_it.arb`: `"Scade ora"`, `"Scade oggi"`, `"Scade tra {count} min"`, `"{count, plural, =1{Scade tra 1 ora} other{Scade tra {count} ore}}"`, `"{count, plural, =1{Scade domani} other{Scade tra {count} giorni}}"`, `"Posticipato"`, `"Fatto"`, `"Tra 10 min"`, `"Tra 1 ora"`.

Run `flutter gen-l10n`.

`main.dart`, in `_openNotifications`: build the scheduler with

```dart
    reminders: AndroidReminderScheduler(
      api,
      strings: reminderStrings(l),
      anchorMinutes: () => readDailyListMinutes(KvStore(db)),
    ),
```

(pass `db` into `_openNotifications`), and add to `android_reminder_scheduler.dart`:

```dart
/// [ReminderStrings] in [l]'s language; shared by the app and the
/// background isolate.
ReminderStrings reminderStrings(L l) => ReminderStrings(
  channelName: l.remindersChannelName,
  channelDescription: l.remindersChannelDescription,
  dueNow: l.remindDueNow,
  dueToday: l.remindDueToday,
  dueInMinutes: l.remindDueInMinutes,
  dueInHours: l.remindDueInHours,
  dueInDays: l.remindDueInDays,
  snoozed: l.remindSnoozed,
  done: l.remindActionDone,
  snooze10: l.remindActionSnooze10,
  snooze60: l.remindActionSnooze60,
);
```

and to `kv_store.dart` (and use it in `AppBootstrap.load` instead of the inline parse from the daily list plan):

```dart
/// The daily list's time in minutes after midnight; 08:00 until chosen.
Future<int> readDailyListMinutes(KvStore kv) async =>
    int.tryParse(await kv.get(KvKeys.dailyListMinutes) ?? '') ?? 480;
```

- [ ] **Step 5: Run** `flutter test --concurrency=2 test/core/notifications` -- PASS; then `flutter test --concurrency=2 test/features` (repositories and sync call `sync`) -- PASS; `flutter analyze` exit 0.

- [ ] **Step 6: Commit**

```bash
git add app/lib/core/notifications app/lib/core/db/kv_store.dart app/lib/core/providers.dart app/lib/main.dart app/lib/l10n app/test/support/fake_notifications.dart app/test/core/notifications
git commit -m "feat(app): remind at each offset, with Done and Snooze buttons

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Handling Done and Snooze, in the app and in the background

**Files:**
- Create: `app/lib/core/notifications/reminder_actions.dart`
- Modify: `app/lib/core/db/app_database.dart` (`shareAcrossIsolates`)
- Modify: `app/android/app/src/main/AndroidManifest.xml` (action receiver)
- Modify: `app/lib/features/sync/ui/sync_engine.dart` (take in the persisted HLC on resume)
- Test: `app/test/core/notifications/reminder_actions_test.dart`

**Interfaces:**
- Consumes: `AndroidReminderScheduler.snooze`, `taskIdFromPayload`, action id constants (Task 4); `TasksRepository.setDone`.
- Produces:
  ```dart
  Future<void> handleReminderAction(String actionId, String? payload, {
    required TasksRepository tasks, required AndroidReminderScheduler reminders});
  @pragma('vm:entry-point') void onReminderActionInBackground(NotificationResponse response);
  ```

- [ ] **Step 1: Failing test** -- `reminder_actions_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/notifications/android_reminder_scheduler.dart';
import 'package:nemo/core/notifications/reminder_actions.dart';
import 'package:nemo/features/lists/data/lists_repository.dart';
import 'package:nemo/features/tasks/data/tasks_repository.dart';
import 'package:nemo_core/nemo_core.dart';

import '../../support/fake_notifications.dart';
import '../../support/test_db.dart';

void main() {
  late AppDatabase db;
  late FakeApi api;
  late AndroidReminderScheduler reminders;
  late TasksRepository tasks;
  late String inbox;

  String payload(String id) => '/tasks/$id';

  setUp(() async {
    db = testDatabase();
    addTearDown(db.close);
    api = FakeApi();
    final clock = testClock();
    final ids = sequentialIds();
    inbox = (await ListsRepository(db, clock, ids).ensureInbox()).id;
    reminders = AndroidReminderScheduler(
      api,
      strings: testReminderStrings,
      anchorMinutes: () async => 480,
      now: () => testNow,
    );
    tasks = TasksRepository(
      db,
      clock,
      ids,
      reminders: reminders,
      now: () => testNow,
    );
  });

  Future<Task> dentist({String? repeat}) async {
    final t = await tasks.create(
      listId: inbox,
      title: 'Dentist',
      dueAt: testNow.add(const Duration(hours: 3)).millisecondsSinceEpoch,
      dueHasTime: true,
      repeat: repeat == null ? null : Repeat.tryParse(repeat),
    );
    final withReminders = t.withReminders([0, 60]);
    await tasks.save(withReminders);
    return withReminders;
  }

  test('done ticks the task off, stamps it and clears its reminders',
      () async {
    final t = await dentist();
    await handleReminderAction(
      reminderActionDone,
      payload(t.id),
      tasks: tasks,
      reminders: reminders,
    );
    final saved = (await db.taskById(t.id))!;
    expect(saved.done, isTrue);
    expect(saved.updatedAt, isNot(t.updatedAt));
    expect(await KvStore(db).get(KvKeys.hlcLast), saved.updatedAt);
    expect(api.scheduled, isEmpty);
  });

  test('done rolls a repeating task on with its reminders', () async {
    final t = await dentist(repeat: 'daily');
    await handleReminderAction(
      reminderActionDone,
      payload(t.id),
      tasks: tasks,
      reminders: reminders,
    );
    final open = await tasks.watchOpenDated().first;
    expect(open, hasLength(1));
    expect(open.single.id, isNot(t.id));
    expect(open.single.reminders, [0, 60]);
    expect(
      api.scheduled.keys,
      contains(AndroidReminderScheduler.notificationId(open.single.id, 0)),
    );
  });

  test('snooze posts again in 10 minutes or an hour', () async {
    final t = await dentist();
    await handleReminderAction(
      reminderActionSnooze60,
      payload(t.id),
      tasks: tasks,
      reminders: reminders,
    );
    expect(
      api.scheduled[AndroidReminderScheduler.snoozeId(t.id)]!.at,
      testNow.add(const Duration(hours: 1)).millisecondsSinceEpoch,
    );
    await handleReminderAction(
      reminderActionSnooze10,
      payload(t.id),
      tasks: tasks,
      reminders: reminders,
    );
    expect(
      api.scheduled[AndroidReminderScheduler.snoozeId(t.id)]!.at,
      testNow.add(const Duration(minutes: 10)).millisecondsSinceEpoch,
    );
  });

  test('done on a done or missing task does nothing', () async {
    final t = await dentist();
    await tasks.setDone(t.id, done: true);
    final before = (await db.taskById(t.id))!;
    for (final action in [reminderActionDone, reminderActionSnooze10]) {
      await handleReminderAction(
        action,
        payload(t.id),
        tasks: tasks,
        reminders: reminders,
      );
      await handleReminderAction(
        action,
        payload('gone'),
        tasks: tasks,
        reminders: reminders,
      );
    }
    expect(await db.taskById(t.id), before);
    expect(await db.taskById('gone'), isNull);
    expect(
      api.scheduled.containsKey(AndroidReminderScheduler.snoozeId(t.id)),
      isFalse,
    );
  });

  test('an unknown action or payload is ignored', () async {
    final t = await dentist();
    await handleReminderAction('reply', payload(t.id),
        tasks: tasks, reminders: reminders);
    await handleReminderAction(reminderActionDone, '/today',
        tasks: tasks, reminders: reminders);
    expect((await db.taskById(t.id))!.done, isFalse);
  });
}
```

Add to `test/support/fake_notifications.dart` a `const testReminderStrings = ReminderStrings(...)` with the same English values as the scheduler test's `strings` (move them there and have the scheduler test use it too). If `Repeat.tryParse('daily')` is not the rule syntax, use the spelling `packages/nemo_core/lib/src/repeat.dart` documents for "every day".

- [ ] **Step 2: Run** `flutter test test/core/notifications/reminder_actions_test.dart` -- fails to compile.

- [ ] **Step 3: Implement** `reminder_actions.dart`:

```dart
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/notifications/android_reminder_scheduler.dart';
import 'package:nemo/core/notifications/notifications_api.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/features/tasks/data/tasks_repository.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo_core/nemo_core.dart';
import 'package:uuid/uuid.dart';

/// Done or Snooze from a reminder's button, for the task its [payload]
/// names. A task that is gone or already done is left alone: the button
/// may be older than a change synced from elsewhere.
Future<void> handleReminderAction(
  String actionId,
  String? payload, {
  required TasksRepository tasks,
  required AndroidReminderScheduler reminders,
}) async {
  final id = taskIdFromPayload(payload);
  if (id == null) return;
  final task = await tasks.byId(id);
  if (task == null || task.done || task.isDeleted) return;
  switch (actionId) {
    case reminderActionDone:
      await tasks.setDone(id, done: true);
    case reminderActionSnooze10:
      await reminders.snooze(task, const Duration(minutes: 10));
    case reminderActionSnooze60:
      await reminders.snooze(task, const Duration(hours: 1));
  }
}

/// A reminder's button tapped while the app is not running: Android starts
/// this in a fresh isolate, which opens the database itself.
@pragma('vm:entry-point')
Future<void> onReminderActionInBackground(NotificationResponse response) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  final api = LocalNotificationsApi();
  await api.initialize();
  final l = await L.delegate.load(PlatformDispatcher.instance.locale);
  final strings = reminderStrings(l);
  final db = AppDatabase.open();
  try {
    final boot = await AppBootstrap.load(db);
    final reminders = AndroidReminderScheduler(
      api,
      strings: strings,
      anchorMinutes: () => readDailyListMinutes(KvStore(db)),
    );
    final tasks = TasksRepository(
      db,
      HlcClock(node: boot.nodeId, last: boot.hlcLast),
      const Uuid().v4,
      reminders: reminders,
    );
    await handleReminderAction(
      response.actionId ?? '',
      response.payload,
      tasks: tasks,
      reminders: reminders,
    );
    // Whatever went wrong, the tap must not vanish: bring the task back as
    // a plain notification that opens it.
    // ignore: avoid_catches_without_on_clauses
  } catch (error) {
    debugPrint('Reminder action failed: $error');
    final id = taskIdFromPayload(response.payload);
    if (id != null) {
      await api.scheduleAt(
        id: AndroidReminderScheduler.snoozeId(id),
        title: strings.dueNow,
        body: '',
        epochMs: DateTime.now()
            .add(const Duration(seconds: 2))
            .millisecondsSinceEpoch,
        channelName: strings.channelName,
        channelDescription: strings.channelDescription,
        payload: response.payload,
      );
    }
  } finally {
    await db.close();
  }
}
```

`TasksRepository.byId` -- add if missing:

```dart
  Future<Task?> byId(String id) => _db.taskById(id);
```

In `main.dart`'s `_openNotifications`, initialise with both callbacks; the foreground one needs the repository, which lives in the provider scope, so route it through a notifier the app listens to:

```dart
  await api.initialize(
    onTap: (payload) => tapped.value = payload,
    onAction: (action, payload) =>
        actions.value = (action: action, payload: payload),
    onBackground: onReminderActionInBackground,
  );
```

with `final actions = ValueNotifier<({String action, String? payload})?>(null);` created in `main` next to `tapped`, overridden into a new `notificationActionProvider` (in `providers.dart`, same shape as `notificationRouteProvider`). In `NemoApp.initState` add a listener that, when the value is non-null, clears it and calls:

```dart
unawaited(handleReminderAction(
  value.action,
  value.payload,
  tasks: ref.read(tasksRepositoryProvider),
  reminders: ref.read(reminderSchedulerProvider) as AndroidReminderScheduler,
));
```

guarded by `if (ref.read(reminderSchedulerProvider) case final AndroidReminderScheduler r)`.

`app_database.dart` -- in `AppDatabase.open`, add to `driftDatabase(...)`:

```dart
      // Reminder buttons run in a background isolate; sharing keeps one
      // writer and lets the running app's streams see their changes.
      native: const DriftNativeOptions(shareAcrossIsolates: true),
```

`AndroidManifest.xml` -- beside the two existing receivers:

```xml
        <receiver android:exported="false"
            android:name="com.dexterous.flutterlocalnotifications.ActionBroadcastReceiver" />
```

`sync_engine.dart` -- in `didChangeAppLifecycleState`, on `resumed`, before requesting a sync, bring the clock up to what a background write stored:

```dart
      unawaited(_catchUpClock());
```

```dart
  /// A reminder's Done may have stamped a row from a background isolate
  /// while the app slept; never issue a stamp behind it.
  Future<void> _catchUpClock() async {
    final stored = await ref.read(kvStoreProvider).get(KvKeys.hlcLast);
    if (stored != null) ref.read(hlcClockProvider).receive(Hlc.parse(stored));
  }
```

(Put it in whichever class owns `didChangeAppLifecycleState`; it has `ref`.)

- [ ] **Step 4: Run** `flutter test test/core/notifications/reminder_actions_test.dart` -- PASS; then `flutter test --concurrency=2` whole suite -- PASS; `flutter analyze` exit 0.

- [ ] **Step 5: Commit**

```bash
git add app/lib/core/notifications/reminder_actions.dart app/lib/core/db/app_database.dart app/lib/core/providers.dart app/lib/features/tasks/data/tasks_repository.dart app/lib/features/sync/ui/sync_engine.dart app/lib/main.dart app/lib/app.dart app/android/app/src/main/AndroidManifest.xml app/test/support/fake_notifications.dart app/test/core/notifications
git commit -m "feat(app): tick off or snooze a task from its reminder

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Moving all-day reminders with the daily list time

**Files:**
- Modify: `app/lib/features/daily_list/daily_list_providers.dart`
- Test: `app/test/features/daily_list/daily_list_providers_test.dart` (append)

**Interfaces:**
- Consumes: `dailyListMinutesProvider`, `reminderSchedulerProvider`, `TasksRepository.watchOpenDated`.
- Produces: the refresher also re-syncs every open dated task's reminders when the daily list time changes.

- [ ] **Step 1: Failing test** -- append to `daily_list_providers_test.dart`, with a recording `ReminderScheduler` override (`synced` list, like `tasks_repository_test.dart`'s `RecordingScheduler`) added to the container's overrides in `setUp`:

```dart
  test('changing the daily list time re-syncs reminders', () async {
    final tasks = container.read(tasksRepositoryProvider);
    await tasks.create(
      listId: inbox,
      title: 'All day',
      dueAt: testNow.millisecondsSinceEpoch,
    );
    await settle();
    recording.synced.clear();
    await container.read(dailyListMinutesProvider.notifier).set(420);
    await settle();
    expect(recording.synced.map((t) => t.title), ['All day']);
  });
```

- [ ] **Step 2: Run** -- FAIL (no re-sync).

- [ ] **Step 3: Implement** -- in `dailyListRefresherProvider`, replace the minutes listener with:

```dart
    ..listen(dailyListMinutesProvider, (_, _) {
      schedule();
      // All-day reminders are anchored at this time.
      unawaited(() async {
        final reminders = ref.read(reminderSchedulerProvider);
        for (final task
            in await ref.read(tasksRepositoryProvider).watchOpenDated().first) {
          await reminders.sync(task);
        }
      }());
    });
```

- [ ] **Step 4: Run** `flutter test --concurrency=2 test/features/daily_list` -- PASS; `flutter analyze` exit 0.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/daily_list/daily_list_providers.dart app/test/features/daily_list/daily_list_providers_test.dart
git commit -m "feat(app): move all-day reminders when the daily list time changes

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Choosing reminders on a task

**Files:**
- Create: `app/lib/features/tasks/ui/reminders_sheet.dart`
- Modify: `app/lib/features/tasks/ui/task_detail_sections.dart`
- Modify: `app/lib/features/tasks/ui/reschedule_sheet.dart`
- Modify: `app/lib/features/tasks/data/tasks_repository.dart` (`create(remind:)` → `create(reminders:)`)
- Modify: `app/lib/l10n/app_en.arb`, `app_de.arb`, `app_it.arb`
- Modify: `CHANGELOG.md`, `README.md`
- Test: `app/test/features/tasks/task_detail_screen_test.dart` (append; update the existing `task-remind` test to the new row), `app/test/features/tasks/tag_and_reschedule_test.dart` (append)

**Interfaces:**
- Consumes: `timedPresets`, `allDayPresets` (Task 3), `Task.withReminders`/`effectiveReminders` (Task 1).
- Produces: `Key('task-reminders')` row; `Key('reminder-chip-<offset>')` chips; `String reminderLabel(L l, int offset, {required bool allDay})`; `String remindersSummary(L l, Task task)`.

- [ ] **Step 1: Failing widget tests** -- append to `task_detail_screen_test.dart` (follow how that file opens a task and overrides providers; it already has a `task-remind` test to copy the setup from, including `remindersSupportedProvider.overrideWithValue(true)` and a permission-granting scheduler):

```dart
  appTest('reminders row summarises and the sheet toggles presets',
      (tester) async {
    final app = await pumpTask(tester, dueAt: dueTomorrowAt14, hasTime: true);
    expect(find.text('None'), findsOneWidget);
    await tester.tap(find.byKey(const Key('task-reminders')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reminder-chip-0')));
    await tester.tap(find.byKey(const Key('reminder-chip-1440')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10)); // close the sheet
    await tester.pumpAndSettle();
    final saved = (await app.db.taskById(taskId))!;
    expect(saved.reminders, [0, 1440]);
    expect(saved.remind, isTrue);
    expect(find.text('At due time, 1 day before'), findsOneWidget);
  });

  appTest('an all-day task offers only day presets', (tester) async {
    await pumpTask(tester, dueAt: dueTomorrow, hasTime: false);
    await tester.tap(find.byKey(const Key('task-reminders')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reminder-chip-15')), findsNothing);
    expect(find.text('That morning'), findsOneWidget);
  });

  appTest('clearing the due date clears reminders', (tester) async {
    final app = await pumpTask(
      tester,
      dueAt: dueTomorrowAt14,
      hasTime: true,
      reminders: [0],
    );
    await tester.tap(find.byKey(const Key('task-clear-date')));
    await tester.pumpAndSettle();
    final saved = (await app.db.taskById(taskId))!;
    expect(saved.reminders, isEmpty);
    expect(saved.remind, isFalse);
  });

  appTest('the row is disabled without a due date', (tester) async {
    await pumpTask(tester);
    expect(
      tester.widget<ListTile>(find.byKey(const Key('task-reminders'))).enabled,
      isFalse,
    );
  });
```

`pumpTask`, `taskId`, `dueTomorrow`, `dueTomorrowAt14` are small helpers to write at the top of the appended block: `pumpApp` with `initialLocation: Routes.task(taskId)`, the Android overrides, and a `seed` that upserts one task (`id: taskId`) with the given due date, `dueHasTime`, and `.withReminders(reminders ?? [])`. Replace the old `task-remind` test's finder and expectations with the row (it was the only user of that key).

Append to `tag_and_reschedule_test.dart`: moving a task with reminders to "No date" leaves `reminders` empty and `remind` false; Undo restores `[0]`.

- [ ] **Step 2: Run** both files -- FAIL.

- [ ] **Step 3: Implement**

l10n -- `app_en.arb`:

```json
  "remindersRow": "Reminders",
  "remindersNone": "None",
  "remindAtDue": "At due time",
  "remindThatMorning": "That morning",
  "remindMinutesBefore": "{count} min before",
  "@remindMinutesBefore": {"placeholders": {"count": {"type": "int"}}},
  "remindHoursBefore": "{count, plural, =1{1 hour before} other{{count} hours before}}",
  "@remindHoursBefore": {"placeholders": {"count": {"type": "int"}}},
  "remindDaysBefore": "{count, plural, =1{1 day before} other{{count} days before}}",
  "@remindDaysBefore": {"placeholders": {"count": {"type": "int"}}},
  "remindWeekBefore": "1 week before",
```

de: `"Erinnerungen"`, `"Keine"`, `"Zum Fälligkeitszeitpunkt"`, `"Am Morgen"`, `"{count} Min. vorher"`, `"{count, plural, =1{1 Stunde vorher} other{{count} Stunden vorher}}"`, `"{count, plural, =1{1 Tag vorher} other{{count} Tage vorher}}"`, `"1 Woche vorher"`.
it: `"Promemoria"`, `"Nessuno"`, `"All'ora di scadenza"`, `"Quella mattina"`, `"{count} min prima"`, `"{count, plural, =1{1 ora prima} other{{count} ore prima}}"`, `"{count, plural, =1{1 giorno prima} other{{count} giorni prima}}"`, `"1 settimana prima"`.

Remove `tasksRemind` from all three arb files once nothing uses it. Run `flutter gen-l10n`.

`reminders_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:nemo/core/notifications/reminder_presets.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo_core/nemo_core.dart';

/// How one offset reads, on a chip and in the summary.
String reminderLabel(L l, int offset, {required bool allDay}) {
  if (offset == 0) return allDay ? l.remindThatMorning : l.remindAtDue;
  if (offset == 10080) return l.remindWeekBefore;
  if (offset >= 1440) return l.remindDaysBefore(offset ~/ 1440);
  if (offset >= 60) return l.remindHoursBefore(offset ~/ 60);
  return l.remindMinutesBefore(offset);
}

/// "At due time, 1 day before", or "None".
String remindersSummary(L l, Task task) {
  final offsets = task.effectiveReminders;
  if (offsets.isEmpty) return l.remindersNone;
  return offsets
      .map((o) => reminderLabel(l, o, allDay: !task.dueHasTime))
      .join(', ');
}

/// Preset chips for [task]; every toggle saves through [onChanged].
Future<void> showRemindersSheet(
  BuildContext context, {
  required Task task,
  required Future<void> Function(List<int> offsets) onChanged,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (context) => _RemindersSheet(task: task, onChanged: onChanged),
);

class _RemindersSheet extends StatefulWidget {
  const _RemindersSheet({required this.task, required this.onChanged});
  final Task task;
  final Future<void> Function(List<int> offsets) onChanged;

  @override
  State<_RemindersSheet> createState() => _RemindersSheetState();
}

class _RemindersSheetState extends State<_RemindersSheet> {
  late final Set<int> _chosen = widget.task.effectiveReminders.toSet();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final allDay = !widget.task.dueHasTime;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final offset in allDay ? allDayPresets : timedPresets)
            FilterChip(
              key: Key('reminder-chip-$offset'),
              label: Text(reminderLabel(l, offset, allDay: allDay)),
              selected: _chosen.contains(offset),
              onSelected: (on) {
                setState(() => on ? _chosen.add(offset) : _chosen.remove(offset));
                widget.onChanged(_chosen.toList());
              },
            ),
        ],
      ),
    );
  }
}
```

`task_detail_sections.dart` -- replace the `SwitchListTile(key: Key('task-remind') …)` with:

```dart
        ListTile(
          key: const Key('task-reminders'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.notifications_outlined),
          title: Text(l.remindersRow),
          subtitle: Text(
            remindersSupported
                ? remindersSummary(l, task)
                : l.tasksRemindUnavailable,
          ),
          enabled: dueAt != null && remindersSupported,
          onTap: () => showRemindersSheet(
            context,
            task: task,
            onChanged: (offsets) async {
              // Asked once, the first time a reminder is chosen.
              if (offsets.isNotEmpty &&
                  task.effectiveReminders.isEmpty &&
                  !await ref.read(reminderSchedulerProvider).ensurePermission()) {
                return;
              }
              await save(task.withReminders(offsets));
            },
          ),
        ),
```

Note `task` in the closure is the value when the sheet opened; since each chip saves the whole chosen set, that is correct. The clear-date chip: `save(task.copyWith(dueAt: null, dueHasTime: false).withReminders(const []))`.

`reschedule_sheet.dart` line ~92: `task.copyWith(dueAt: null, dueHasTime: false).withReminders(const [])`; Undo: `moved.copyWith(dueAt: task.dueAt, dueHasTime: task.dueHasTime, remind: task.remind, reminders: task.reminders)`.

`tasks_repository.dart` `create`: replace `bool remind = false` with `List<int> reminders = const []`, and in the body `remind: …` with `.withReminders(dueAt == null ? const [] : reminders)` applied to the built `Task`. Fix every caller the analyzer reports (`remind: true` → `reminders: const [0]`).

`CHANGELOG.md`, under `## Unreleased`, `### Added`:

```markdown
- Reminders before a task is due: pick any of at the due time, 5, 15 or
  30 minutes, 1 or 2 hours, 1 or 2 days, or a week before -- as many as
  you like. A task without a time is reminded at your daily list time.
- Done and Snooze (10 minutes or an hour) right on a reminder, without
  opening the app.
```

and `### Changed`:

```markdown
- Update the server together with the app: an older server, or an older
  app on another device, keeps only "remind at the due time" for a task
  it edits.
```

`README.md`: extend the reminders mention: `…due dates with reminders (several per task, with Done and Snooze on the notification)…`.

- [ ] **Step 4: Run** `flutter test --concurrency=2 test/features/tasks` -- PASS; whole app suite `flutter test --concurrency=2` -- PASS; `cd ../server && dart test` -- PASS; `cd ../packages/nemo_core && dart test` -- PASS; `flutter analyze` exit 0; `dart format` the three packages.

- [ ] **Step 5: Manual check on a device** (for the human; no Android SDK here): a timed task due in 20 min with "15 min before" and "At due time" → two notifications five minutes apart. On the first, Snooze 10 min → it returns 10 min later. Kill the app; on a reminder tap Done → the notification goes; open the app → the task is ticked off, and a repeating one shows its next occurrence. An all-day task with "That morning" → notification at the daily list time.

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/tasks app/lib/l10n app/test/features/tasks CHANGELOG.md README.md
git commit -m "feat(app): choose several reminders per task

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
