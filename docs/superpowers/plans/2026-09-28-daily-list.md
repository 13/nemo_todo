# Daily List Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Once a day, at a chosen time, the Android app posts one local notification listing today's open and overdue tasks; nothing due means no notification; tapping opens Today.

**Architecture:** A pure `buildDigest` turns tasks into a digest for one morning. `AndroidDailyDigestScheduler.refresh()` schedules the next seven mornings (ids `-1..-7`) through the existing `NotificationsApi`, which learns a channel id, inbox lines, a payload and a tap callback. A keep-alive provider refreshes it (debounced) whenever open dated tasks change, a setting changes, or the app resumes. Settings get a switch and a time.

**Tech Stack:** Flutter 3.47 (fvm), Riverpod 3 with riverpod_generator, drift, flutter_local_notifications 22.3, flutter_test with `pumpApp`/`appTest`.

**Spec:** `docs/superpowers/specs/2026-09-28-daily-list-design.md`

## Global Constraints

- Android only: everything is a no-op where `remindersSupportedProvider` is false (web, widget tests); no server, schema or sync change.
- Contents: open, undeleted, dated tasks in undeleted lists with `dueAt < dayStartMsFrom(fireAt, 1)`; overdue = `dueAt < dayStartMs(fireAt)`; overdue first, then today, each in Today's due order.
- Empty day: no notification. Default off; default time 08:00 (`480` minutes).
- Title: `dailyListToday(n)` when nothing is overdue, `dailyListOverdue(n)` when nothing is due today, else `dailyListTodayOverdue(today, overdue)`. Body: first titles joined by `", "`. Expanded: at most 6 titles, then `dailyListMore(n)`.
- Channel id `daily_list`; notification ids `-1..-7` (`dailyDigestId(i) = -(i + 1)`); payload `/today`.
- Seven mornings scheduled ahead; each built as a local `DateTime(y, m, d + i, h, min)`.
- Refused permission when switching on: the switch stays off (same as the task sheet's reminder switch).
- A notification error never fails a task write or a setting change: caught and `debugPrint`ed.
- Toolchain: `export PATH=~/fvm/versions/3.47.2/bin:$PATH`, run from `app/`; codegen `dart run build_runner build --delete-conflicting-outputs`; l10n `flutter gen-l10n`; `flutter test --concurrency=2 <file or dir>`, one process at a time, 600 s timeout; `flutter analyze` clean before each commit.
- Commits end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Branch `feat/daily-list` off `main` (create it before Task 1).

## Review Focus

- A task ticked off in the evening must vanish from tomorrow's scheduled list: the refresher must fire on `done` changes (they change `watchOpenDated`'s result) -- Task 5 test "a write reschedules once".
- The chosen time already passed today: first morning is tomorrow, not an immediate notification -- Task 3 test "time passed today starts tomorrow".
- Daylight-saving week: every scheduled morning is 08:00 local, not 07:00/09:00 -- Task 3 test "keeps the wall-clock time across a DST change".
- Turning the switch off must remove all seven already scheduled mornings, not just stop adding new ones -- Task 3 test "off cancels all seven".
- A burst of writes (sync applying 200 rows) must not run 200 refreshes in parallel -- Task 3 test "a refresh during a refresh runs once more" and Task 5 "a write reschedules once".

---

### Task 1: NotificationsApi learns channels, inbox lines, payloads and taps

**Files:**
- Modify: `app/lib/core/notifications/notifications_api.dart`
- Modify: `app/lib/core/notifications/reminder_scheduler.dart` (drop `init`)
- Modify: `app/lib/core/notifications/android_reminder_scheduler.dart` (drop `init`)
- Modify: `app/lib/main.dart` (initialise the api itself)
- Modify: `app/test/core/notifications/notifications_api_test.dart`
- Modify: `app/test/core/notifications/android_reminder_scheduler_test.dart`
- Modify: `app/test/features/tasks_repository_test.dart`, `app/test/features/lists_repository_test.dart` (their `RecordingScheduler` drops `init`)

**Interfaces:**
- Produces:
  ```dart
  abstract interface class NotificationsApi {
    Future<void> initialize({void Function(String? payload)? onTap});
    Future<bool> requestPermission();
    Future<void> scheduleAt({
      required int id, required String title, required String body,
      required int epochMs, required String channelName,
      required String channelDescription,
      String channelId = 'reminders', List<String>? lines, String? payload,
    });
    Future<void> cancel(int id);
    Future<String?> launchPayload();
  }
  ```
  `ReminderScheduler` no longer has `init()`; the api is initialised once in `main`.

- [ ] **Step 1: Failing tests** -- in `notifications_api_test.dart`, extend the mock handler to answer `getNotificationAppLaunchDetails` and add:

```dart
  test('schedules on a given channel with inbox lines and a payload', () async {
    final notifications = api();
    await notifications.initialize();
    await notifications.scheduleAt(
      id: -1,
      title: '3 tasks today',
      body: 'Dentist, Milk, Taxes',
      epochMs: DateTime.utc(2099, 9, 7, 6).millisecondsSinceEpoch,
      channelName: 'Daily list',
      channelDescription: 'desc',
      channelId: 'daily_list',
      lines: ['Dentist', 'Milk', 'Taxes'],
      payload: '/today',
    );
    final args =
        calls.singleWhere((c) => c.method == 'zonedSchedule').arguments
            as Map<Object?, Object?>;
    expect(args['id'], -1);
    expect(args['payload'], '/today');
    final specifics = args['platformSpecifics']! as Map<Object?, Object?>;
    expect(specifics['channelId'], 'daily_list');
    final style = specifics['styleInformation']! as Map<Object?, Object?>;
    expect(style['lines'], ['Dentist', 'Milk', 'Taxes']);
  });

  test('no launch payload when the app was not opened from one', () async {
    expect(await api().launchPayload(), isNull);
  });
```

Mock handler addition (inside the existing `switch`):

```dart
            'getNotificationAppLaunchDetails' => null,
```

In the existing 'schedules a reminder…' test, keep asserting `channelId == 'reminders'` (the default).

- [ ] **Step 2: Run** `flutter test --concurrency=2 test/core/notifications/notifications_api_test.dart` -- fails to compile (`channelId`, `lines`, `payload`, `launchPayload` undefined).

- [ ] **Step 3: Implement** in `notifications_api.dart`:

```dart
abstract interface class NotificationsApi {
  /// Sets the plugin up once per process. [onTap] receives the payload of a
  /// notification tapped while the app is running.
  Future<void> initialize({void Function(String? payload)? onTap});
  Future<bool> requestPermission();
  Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required int epochMs,
    required String channelName,
    required String channelDescription,
    String channelId = 'reminders',
    // Shown one per line when the notification is expanded.
    List<String>? lines,
    String? payload,
  });
  Future<void> cancel(int id);

  /// The payload of the notification whose tap started the app, if one did.
  Future<String?> launchPayload();
}
```

`LocalNotificationsApi`:

```dart
  @override
  Future<void> initialize({void Function(String? payload)? onTap}) async {
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        // (keep the existing comment)
        android: AndroidInitializationSettings('@drawable/ic_notification'),
      ),
      onDidReceiveNotificationResponse: onTap == null
          ? null
          : (response) => onTap(response.payload),
    );
  }

  @override
  Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required int epochMs,
    required String channelName,
    required String channelDescription,
    String channelId = 'reminders',
    List<String>? lines,
    String? payload,
  }) => _plugin.zonedSchedule(
    id: id,
    title: title,
    body: body,
    payload: payload,
    // An absolute instant; the zone only matters for repeating schedules.
    scheduledDate: tz.TZDateTime.fromMillisecondsSinceEpoch(tz.UTC, epochMs),
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
        styleInformation: lines == null ? null : InboxStyleInformation(lines),
      ),
    ),
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
  );

  @override
  Future<String?> launchPayload() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return details.notificationResponse?.payload;
  }
```

Remove `init()` from `ReminderScheduler`, `NoopReminderScheduler`, `AndroidReminderScheduler` and both test `RecordingScheduler`s. In `android_reminder_scheduler_test.dart`: update `FakeApi` to the new interface (below) and change the 'init and permission…' test to only check permission:

```dart
class FakeApi implements NotificationsApi {
  final Map<int, ({String title, String body, int at, String channelId, List<String>? lines, String? payload})> scheduled = {};
  final List<int> cancelled = [];
  bool initialized = false;
  bool permission = true;

  @override
  Future<void> initialize({void Function(String? payload)? onTap}) async =>
      initialized = true;

  @override
  Future<bool> requestPermission() async => permission;

  @override
  Future<void> scheduleAt({
    required int id,
    required String title,
    required String body,
    required int epochMs,
    required String channelName,
    required String channelDescription,
    String channelId = 'reminders',
    List<String>? lines,
    String? payload,
  }) async => scheduled[id] = (
    title: title,
    body: body,
    at: epochMs,
    channelId: channelId,
    lines: lines,
    payload: payload,
  );

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    scheduled.remove(id);
  }

  @override
  Future<String?> launchPayload() async => null;
}
```

Move this `FakeApi` to `app/test/support/fake_notifications.dart` (Task 3 reuses it) and import it from the scheduler test.

In `main.dart`, `_openReminders` becomes:

```dart
/// Local notifications on Android; nothing to schedule elsewhere.
Future<ReminderScheduler> _openReminders() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return const NoopReminderScheduler();
  }
  final l = await L.delegate.load(
    WidgetsBinding.instance.platformDispatcher.locale,
  );
  final api = LocalNotificationsApi();
  await api.initialize();
  return AndroidReminderScheduler(
    api,
    channelName: l.remindersChannelName,
    channelDescription: l.remindersChannelDescription,
    body: l.remindersDueNow,
  );
}
```

(Task 5 reshapes this further; this step only keeps it compiling.)

- [ ] **Step 4: Run** `flutter test --concurrency=2 test/core/notifications test/features/tasks_repository_test.dart test/features/lists_repository_test.dart` -- PASS. `flutter analyze` -- clean.

- [ ] **Step 5: Commit**

```bash
git add -A app/lib/core/notifications app/lib/main.dart app/test
git commit -m "refactor(app): notifications take a channel, inbox lines, a payload and taps

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: `buildDigest`

**Files:**
- Create: `app/lib/core/notifications/daily_digest.dart`
- Test: `app/test/core/notifications/daily_digest_test.dart`

**Interfaces:**
- Produces:
  ```dart
  class Digest { final int todayCount; final int overdueCount; final List<String> lines; final int more; }
  const digestMaxLines = 6;
  Digest? buildDigest(List<Task> tasks, DateTime fireAt);
  ```
  `tasks` are expected in Today's due order (as `TasksRepository.watchOpenDated` emits them); `buildDigest` keeps that order within overdue and within today.

- [ ] **Step 1: Failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/notifications/daily_digest.dart';
import 'package:nemo_core/nemo_core.dart';

void main() {
  final fireAt = DateTime(2026, 9, 28, 8);

  Task task(
    String title,
    DateTime? due, {
    bool done = false,
    String? deletedAt,
  }) => Task(
    id: title,
    listId: 'l',
    title: title,
    sortKey: 'V',
    updatedAt: '0000000000001-0000-n',
    dueAt: due?.millisecondsSinceEpoch,
    done: done,
    deletedAt: deletedAt,
  );

  test('nothing due gives no digest', () {
    expect(buildDigest([], fireAt), isNull);
    expect(
      buildDigest([task('Later', DateTime(2026, 9, 29, 9))], fireAt),
      isNull,
    );
  });

  test('counts today and overdue, overdue first', () {
    final digest = buildDigest([
      task('Old', DateTime(2026, 9, 26)),
      task('Morning', DateTime(2026, 9, 28, 7)),
      task('Yesterday', DateTime(2026, 9, 27, 18)),
      task('Evening', DateTime(2026, 9, 28, 19)),
      task('All day', DateTime(2026, 9, 28)),
    ], fireAt)!;
    expect(digest.overdueCount, 2);
    expect(digest.todayCount, 3);
    expect(digest.lines, ['Old', 'Yesterday', 'Morning', 'Evening', 'All day']);
    expect(digest.more, 0);
  });

  test('leaves out done, deleted and undated tasks', () {
    final digest = buildDigest([
      task('Done', DateTime(2026, 9, 28, 9), done: true),
      task('Deleted', DateTime(2026, 9, 28, 9), deletedAt: 'x'),
      task('Undated', null),
      task('Kept', DateTime(2026, 9, 28, 9)),
    ], fireAt)!;
    expect(digest.lines, ['Kept']);
  });

  test('caps the lines at six and counts the rest', () {
    final digest = buildDigest([
      for (var i = 0; i < 9; i++) task('T$i', DateTime(2026, 9, 28, 9)),
    ], fireAt)!;
    expect(digest.lines, hasLength(digestMaxLines));
    expect(digest.more, 3);
  });

  test("a task due tomorrow is only in tomorrow's digest", () {
    final tasks = [task('Tomorrow', DateTime(2026, 9, 29, 9))];
    expect(buildDigest(tasks, fireAt), isNull);
    final next = buildDigest(tasks, DateTime(2026, 9, 29, 8))!;
    expect(next.todayCount, 1);
    final after = buildDigest(tasks, DateTime(2026, 9, 30, 8))!;
    expect(after.overdueCount, 1);
  });
}
```

- [ ] **Step 2: Run** `flutter test --concurrency=2 test/core/notifications/daily_digest_test.dart` -- fails (file missing).

- [ ] **Step 3: Implement** `daily_digest.dart`:

```dart
import 'dart:math';

import 'package:nemo/utils/dates.dart';
import 'package:nemo_core/nemo_core.dart';

/// What the daily list says on one morning.
class Digest {
  const Digest({
    required this.todayCount,
    required this.overdueCount,
    required this.lines,
    required this.more,
  });

  final int todayCount;
  final int overdueCount;

  /// Titles shown when the notification is expanded, overdue first.
  final List<String> lines;

  /// Tasks not in [lines].
  final int more;
}

/// How many titles an expanded daily list shows.
const digestMaxLines = 6;

/// The daily list for the morning of [fireAt], or null when nothing is due
/// or overdue then.
///
/// [tasks] come in Today's order; that order is kept within the overdue
/// tasks and within today's. Overdue means due before [fireAt]'s day, so a
/// task due at 07:00 counts as today's in an 08:00 list.
Digest? buildDigest(List<Task> tasks, DateTime fireAt) {
  final today = dayStartMs(fireAt);
  final tomorrow = dayStartMsFrom(fireAt, 1);
  final overdue = <Task>[];
  final onDay = <Task>[];
  for (final task in tasks) {
    final dueAt = task.dueAt;
    if (task.done || task.isDeleted || dueAt == null || dueAt >= tomorrow) {
      continue;
    }
    (dueAt < today ? overdue : onDay).add(task);
  }
  final ordered = [...overdue, ...onDay];
  if (ordered.isEmpty) return null;
  final shown = min(ordered.length, digestMaxLines);
  return Digest(
    todayCount: onDay.length,
    overdueCount: overdue.length,
    lines: [for (final t in ordered.take(shown)) t.title],
    more: ordered.length - shown,
  );
}
```

- [ ] **Step 4: Run** the test -- PASS. `flutter analyze` -- clean.

- [ ] **Step 5: Commit**

```bash
git add app/lib/core/notifications/daily_digest.dart app/test/core/notifications/daily_digest_test.dart
git commit -m "feat(app): build a morning's daily list from tasks

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Query and `AndroidDailyDigestScheduler`

**Files:**
- Modify: `app/lib/features/tasks/data/tasks_repository.dart` (add `watchOpenDated`)
- Create: `app/lib/core/notifications/daily_digest_scheduler.dart`
- Test: `app/test/features/tasks_repository_test.dart` (one test), `app/test/core/notifications/daily_digest_scheduler_test.dart`

**Interfaces:**
- Consumes: `NotificationsApi` (Task 1), `buildDigest`/`Digest` (Task 2), `FakeApi` from `app/test/support/fake_notifications.dart` (Task 1).
- Produces:
  ```dart
  Stream<List<Task>> TasksRepository.watchOpenDated();
  class DailyListSettings { const DailyListSettings({required bool enabled, required int minutes}); }
  class DigestStrings { const DigestStrings({required String channelName, required String channelDescription, required String Function(int today, int overdue) title, required String Function(int count) more}); }
  abstract interface class DailyDigestScheduler { Future<void> refresh(); }
  class NoopDailyDigestScheduler implements DailyDigestScheduler { const NoopDailyDigestScheduler(); }
  class AndroidDailyDigestScheduler implements DailyDigestScheduler {
    AndroidDailyDigestScheduler(NotificationsApi api, {required Future<List<Task>> Function() loadTasks, required DailyListSettings Function() settings, required DigestStrings strings, DateTime Function()? now});
  }
  int dailyDigestId(int day); // -(day + 1)
  const dailyDigestDays = 7;
  const dailyDigestChannelId = 'daily_list';
  const dailyDigestPayload = '/today';
  ```

- [ ] **Step 1: Failing repository test** (in `tasks_repository_test.dart`, using its `setUp`):

```dart
  test('watchOpenDated lists open dated tasks in due order', () async {
    int at(int day) => DateTime(2026, 9, day).millisecondsSinceEpoch;
    await tasks.create(listId: inbox, title: 'Later', dueAt: at(9));
    await tasks.create(listId: inbox, title: 'Undated');
    final done = await tasks.create(listId: inbox, title: 'Done', dueAt: at(7));
    await tasks.setDone(done.id, done: true);
    await tasks.create(listId: inbox, title: 'Sooner', dueAt: at(8));
    final titles = [
      for (final t in await tasks.watchOpenDated().first) t.title,
    ];
    expect(titles, ['Sooner', 'Later']);
  });
```

- [ ] **Step 2: Failing scheduler tests** -- `daily_digest_scheduler_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/notifications/daily_digest_scheduler.dart';
import 'package:nemo/router.dart';
import 'package:nemo_core/nemo_core.dart';

import '../../support/fake_notifications.dart';

void main() {
  late FakeApi api;
  late List<Task> tasks;
  late DailyListSettings settings;
  late DateTime now;

  Task task(String title, DateTime due) => Task(
    id: title,
    listId: 'l',
    title: title,
    sortKey: 'V',
    updatedAt: '0000000000001-0000-n',
    dueAt: due.millisecondsSinceEpoch,
  );

  AndroidDailyDigestScheduler scheduler() => AndroidDailyDigestScheduler(
    api,
    loadTasks: () async => tasks,
    settings: () => settings,
    strings: DigestStrings(
      channelName: 'Daily list',
      channelDescription: 'desc',
      title: (today, overdue) => '$today/$overdue',
      more: (n) => '+$n more',
    ),
    now: () => now,
  );

  setUp(() {
    api = FakeApi();
    now = DateTime(2026, 9, 28, 7);
    settings = const DailyListSettings(enabled: true, minutes: 8 * 60);
    tasks = [task('Dentist', DateTime(2026, 9, 28, 15))];
  });

  test('payload is the Today route', () {
    expect(dailyDigestPayload, Routes.today);
  });

  test('schedules this morning when the time is still ahead', () async {
    await scheduler().refresh();
    final first = api.scheduled[dailyDigestId(0)]!;
    expect(first.at, DateTime(2026, 9, 28, 8).millisecondsSinceEpoch);
    expect(first.title, '1/0');
    expect(first.body, 'Dentist');
    expect(first.lines, ['Dentist']);
    expect(first.channelId, dailyDigestChannelId);
    expect(first.payload, '/today');
    // Every later morning sees Dentist as overdue.
    for (var i = 1; i < dailyDigestDays; i++) {
      expect(api.scheduled[dailyDigestId(i)]!.title, '0/1');
    }
  });

  test('time passed today starts tomorrow', () async {
    now = DateTime(2026, 9, 28, 9);
    await scheduler().refresh();
    expect(
      api.scheduled[dailyDigestId(0)]!.at,
      DateTime(2026, 9, 29, 8).millisecondsSinceEpoch,
    );
  });

  test('empty mornings are skipped', () async {
    tasks = [task('Friday', DateTime(2026, 10, 2, 9))];
    await scheduler().refresh();
    // 28, 29, 30 Sep and 1 Oct have nothing; 2 Oct onwards do.
    expect(api.scheduled.keys.toSet(), {
      dailyDigestId(4),
      dailyDigestId(5),
      dailyDigestId(6),
    });
  });

  test('off cancels all seven and schedules none', () async {
    await scheduler().refresh();
    settings = const DailyListSettings(enabled: false, minutes: 480);
    await scheduler().refresh();
    expect(api.scheduled, isEmpty);
    for (var i = 0; i < dailyDigestDays; i++) {
      expect(api.cancelled, contains(dailyDigestId(i)));
    }
  });

  test('adds a "more" line past six titles', () async {
    tasks = [for (var i = 0; i < 8; i++) task('T$i', DateTime(2026, 9, 28, 9))];
    await scheduler().refresh();
    final lines = api.scheduled[dailyDigestId(0)]!.lines!;
    expect(lines, hasLength(7));
    expect(lines.last, '+2 more');
  });

  test('keeps the wall-clock time across a DST change', () async {
    // The EU clocks go back on 25 Oct 2026; in any zone each morning must
    // still be 08:00 local.
    now = DateTime(2026, 10, 22, 7);
    tasks = [task('Old', DateTime(2026, 10, 20, 9))];
    await scheduler().refresh();
    for (final s in api.scheduled.values) {
      final local = DateTime.fromMillisecondsSinceEpoch(s.at);
      expect((local.hour, local.minute), (8, 0));
    }
    expect(api.scheduled, hasLength(dailyDigestDays));
  });

  test('a refresh during a refresh runs once more, not in parallel', () async {
    var loads = 0;
    var inFlight = 0;
    var maxInFlight = 0;
    final s = AndroidDailyDigestScheduler(
      api,
      loadTasks: () async {
        loads++;
        inFlight++;
        maxInFlight = inFlight > maxInFlight ? inFlight : maxInFlight;
        await Future<void>.delayed(Duration.zero);
        inFlight--;
        return tasks;
      },
      settings: () => settings,
      strings: DigestStrings(
        channelName: 'c',
        channelDescription: 'd',
        title: (a, b) => '',
        more: (n) => '',
      ),
      now: () => now,
    );
    await Future.wait([s.refresh(), s.refresh(), s.refresh()]);
    expect(maxInFlight, 1);
    expect(loads, 2);
  });

  test('an api error is swallowed', () async {
    api.failSchedule = true;
    await expectLater(scheduler().refresh(), completes);
  });
}
```

Add `bool failSchedule = false;` to `FakeApi`, and at the top of its `scheduleAt`: `if (failSchedule) throw StateError('plugin failed');`.

- [ ] **Step 3: Run** `flutter test --concurrency=2 test/core/notifications/daily_digest_scheduler_test.dart test/features/tasks_repository_test.dart` -- fails to compile.

- [ ] **Step 4: Implement** -- in `tasks_repository.dart`, next to `watchUpcoming`:

```dart
  /// Open tasks with a due date, in Today's order: what the daily list is
  /// built from.
  Stream<List<Task>> watchOpenDated() => _visible(
    _db.tasks.done.equals(false) & _db.tasks.dueAt.isNotNull(),
    _dueOrder,
  );
```

`daily_digest_scheduler.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:nemo/core/notifications/daily_digest.dart';
import 'package:nemo/core/notifications/notifications_api.dart';
import 'package:nemo_core/nemo_core.dart';

/// Whether the daily list is on, and when: minutes after local midnight.
class DailyListSettings {
  const DailyListSettings({required this.enabled, required this.minutes});
  final bool enabled;
  final int minutes;
}

/// Daily list text, from the device locale like the reminder channel's.
class DigestStrings {
  const DigestStrings({
    required this.channelName,
    required this.channelDescription,
    required this.title,
    required this.more,
  });

  final String channelName;
  final String channelDescription;
  final String Function(int today, int overdue) title;
  final String Function(int count) more;
}

/// How many mornings are scheduled ahead, so the list keeps coming on days
/// the app is not opened.
const dailyDigestDays = 7;
const dailyDigestChannelId = 'daily_list';

/// Where a tap on the daily list goes: `Routes.today`, spelled out so this
/// file does not pull in the router and every screen with it.
const dailyDigestPayload = '/today';

/// Notification id of the [day]th scheduled morning. Negative, so it never
/// meets a reminder's, which are `hashCode & 0x7fffffff`.
int dailyDigestId(int day) => -(day + 1);

abstract interface class DailyDigestScheduler {
  /// Replaces the scheduled mornings with ones built from current data.
  Future<void> refresh();
}

/// Web and tests: there is no daily list.
class NoopDailyDigestScheduler implements DailyDigestScheduler {
  const NoopDailyDigestScheduler();

  @override
  Future<void> refresh() async {}
}

class AndroidDailyDigestScheduler implements DailyDigestScheduler {
  AndroidDailyDigestScheduler(
    this._api, {
    required this.loadTasks,
    required this.settings,
    required this.strings,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final NotificationsApi _api;
  final Future<List<Task>> Function() loadTasks;
  final DailyListSettings Function() settings;
  final DigestStrings strings;
  final DateTime Function() _now;

  Future<void>? _running;
  var _again = false;

  /// Runs one rebuild at a time; a call while one runs asks for one more
  /// afterwards, so the last change always wins without piling up.
  @override
  Future<void> refresh() {
    if (_running case final running?) {
      _again = true;
      return running;
    }
    return _running = _drain().whenComplete(() => _running = null);
  }

  Future<void> _drain() async {
    do {
      _again = false;
      try {
        await _rebuild();
        // A notification that cannot be scheduled must not take a task
        // write or a setting down with it.
        // ignore: avoid_catches_without_on_clauses
      } catch (error) {
        debugPrint('Daily list not scheduled: $error');
      }
    } while (_again);
  }

  Future<void> _rebuild() async {
    for (var i = 0; i < dailyDigestDays; i++) {
      await _api.cancel(dailyDigestId(i));
    }
    final s = settings();
    if (!s.enabled) return;
    final now = _now();
    final first = _morning(now, 0, s.minutes).isAfter(now) ? 0 : 1;
    final tasks = await loadTasks();
    for (var i = 0; i < dailyDigestDays; i++) {
      final fireAt = _morning(now, first + i, s.minutes);
      final digest = buildDigest(tasks, fireAt);
      if (digest == null) continue;
      await _api.scheduleAt(
        id: dailyDigestId(i),
        title: strings.title(digest.todayCount, digest.overdueCount),
        body: digest.lines.join(', '),
        lines: [
          ...digest.lines,
          if (digest.more > 0) strings.more(digest.more),
        ],
        epochMs: fireAt.millisecondsSinceEpoch,
        channelId: dailyDigestChannelId,
        channelName: strings.channelName,
        channelDescription: strings.channelDescription,
        payload: dailyDigestPayload,
      );
    }
  }

  /// [minutes] after local midnight, [days] after [now]'s day. Built from
  /// calendar fields, so a daylight-saving change keeps the wall-clock time.
  static DateTime _morning(DateTime now, int days, int minutes) =>
      DateTime(now.year, now.month, now.day + days, minutes ~/ 60, minutes % 60);
}
```

If `very_good_analysis` flags the `catch` differently, use `on Object catch (error)` as `main.dart` does and drop the ignore.

- [ ] **Step 5: Run** both test files -- PASS. `flutter analyze` -- clean.

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/tasks/data/tasks_repository.dart app/lib/core/notifications/daily_digest_scheduler.dart app/test
git commit -m "feat(app): schedule a week of daily lists from current tasks

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Settings -- stored values, strings and the tile

**Files:**
- Modify: `app/lib/core/db/kv_store.dart` (keys)
- Modify: `app/lib/core/providers.dart` (`AppBootstrap` fields)
- Modify: `app/lib/features/settings/ui/settings_controller.dart` (+ regenerated `.g.dart`)
- Create: `app/lib/features/settings/ui/daily_list_tile.dart`
- Modify: `app/lib/features/settings/ui/settings_screen.dart`
- Modify: `app/lib/l10n/app_en.arb`, `app_de.arb`, `app_it.arb` (+ `flutter gen-l10n`)
- Test: `app/test/features/settings/daily_list_tile_test.dart`

**Interfaces:**
- Produces: `KvKeys.dailyList`, `KvKeys.dailyListMinutes`; `AppBootstrap.dailyList` (bool, default false), `AppBootstrap.dailyListMinutes` (int, default 480); generated `dailyListEnabledProvider` (`bool`, notifier `set({required bool enabled})`) and `dailyListMinutesProvider` (`int`, notifier `set(int minutes)`); l10n getters `dailyListTitle`, `dailyListHint`, `dailyListTime`, `dailyListChannelName`, `dailyListChannelDescription`, `dailyListToday(int)`, `dailyListOverdue(int)`, `dailyListTodayOverdue(int today, int overdue)`, `dailyListMore(int)`.

- [ ] **Step 1: Failing widget test** -- `daily_list_tile_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/router.dart';
import 'package:nemo_core/nemo_core.dart';

import '../../support/pump_app.dart';

class PermissionScheduler implements ReminderScheduler {
  PermissionScheduler({required this.granted});
  final bool granted;

  @override
  Future<bool> ensurePermission() async => granted;

  @override
  Future<void> sync(Task task) async {}

  @override
  Future<void> cancel(String taskId) async {}
}

void main() {
  List<Object> android({bool granted = true}) => [
    remindersSupportedProvider.overrideWithValue(true),
    reminderSchedulerProvider.overrideWithValue(
      PermissionScheduler(granted: granted),
    ),
  ];

  appTest('hidden where reminders are unavailable', (tester) async {
    await pumpApp(tester, initialLocation: Routes.settings);
    expect(find.byKey(const Key('daily-list-switch')), findsNothing);
  });

  appTest('starts off at 08:00 and persists the switch', (tester) async {
    final app = await pumpApp(
      tester,
      initialLocation: Routes.settings,
      overrides: android(),
    );
    final finder = find.byKey(const Key('daily-list-switch'));
    await tester.scrollUntilVisible(finder, 200);
    expect(tester.widget<SwitchListTile>(finder).value, isFalse);
    expect(find.text('8:00 AM'), findsOneWidget);

    await tester.tap(finder);
    await tester.pumpAndSettle();
    expect(await KvStore(app.db).get(KvKeys.dailyList), 'true');
    expect(tester.widget<SwitchListTile>(finder).value, isTrue);
  });

  appTest('refused permission leaves it off', (tester) async {
    final app = await pumpApp(
      tester,
      initialLocation: Routes.settings,
      overrides: android(granted: false),
    );
    final finder = find.byKey(const Key('daily-list-switch'));
    await tester.scrollUntilVisible(finder, 200);
    await tester.tap(finder);
    await tester.pumpAndSettle();
    expect(await KvStore(app.db).get(KvKeys.dailyList), isNull);
    expect(tester.widget<SwitchListTile>(finder).value, isFalse);
  });

  appTest('the time is picked and persisted', (tester) async {
    final app = await pumpApp(
      tester,
      initialLocation: Routes.settings,
      overrides: android(),
      seed: (db, _) => KvStore(db).set(KvKeys.dailyList, 'true'),
    );
    final tile = find.byKey(const Key('daily-list-time'));
    await tester.scrollUntilVisible(tile, 200);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    // Switch the Material time picker to text entry, then type 07:30.
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '7');
    await tester.enterText(find.byType(TextField).at(1), '30');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(await KvStore(app.db).get(KvKeys.dailyListMinutes), '450');
    expect(find.text('7:30 AM'), findsOneWidget);
  });

  appTest('the time row is disabled while the list is off', (tester) async {
    await pumpApp(
      tester,
      initialLocation: Routes.settings,
      overrides: android(),
    );
    final tile = find.byKey(const Key('daily-list-time'));
    await tester.scrollUntilVisible(tile, 200);
    expect(tester.widget<ListTile>(tile).enabled, isFalse);
  });
}
```

(If the picker's text-entry toggle icon or field order differs in this Flutter version, look it up in `flutter/lib/src/material/time_picker.dart` and adjust these two lines only.)

- [ ] **Step 2: Run** `flutter test --concurrency=2 test/features/settings/daily_list_tile_test.dart` -- fails to compile.

- [ ] **Step 3: Implement**

`kv_store.dart`, after `currency`:

```dart
  /// The daily list notification: `"true"` when on; unset is off. Its time
  /// in minutes after local midnight; unset is 480 (08:00).
  static const dailyList = 'daily_list';
  static const dailyListMinutes = 'daily_list_minutes';
```

`AppBootstrap`: constructor params `this.dailyList = false, this.dailyListMinutes = 480,`; fields with doc comments (`/// The daily list notification is on.` / `/// When the daily list arrives: minutes after local midnight.`); in `load`:

```dart
      dailyList: await kv.get(KvKeys.dailyList) == 'true',
      dailyListMinutes:
          int.tryParse(await kv.get(KvKeys.dailyListMinutes) ?? '') ?? 480,
```

`settings_controller.dart`:

```dart
/// A morning notification with what is due; off unless chosen.
@Riverpod(keepAlive: true)
class DailyListEnabled extends _$DailyListEnabled {
  @override
  bool build() => ref.watch(bootstrapProvider).dailyList;

  Future<void> set({required bool enabled}) async {
    state = enabled;
    await ref.read(kvStoreProvider).set(KvKeys.dailyList, '$enabled');
  }
}

/// When the daily list arrives: minutes after local midnight.
@Riverpod(keepAlive: true)
class DailyListMinutes extends _$DailyListMinutes {
  @override
  int build() => ref.watch(bootstrapProvider).dailyListMinutes;

  Future<void> set(int minutes) async {
    state = minutes;
    await ref.read(kvStoreProvider).set(KvKeys.dailyListMinutes, '$minutes');
  }
}
```

Run `dart run build_runner build --delete-conflicting-outputs`.

`app_en.arb` (after the `remindersDueNow` entry):

```json
  "dailyListTitle": "Daily list",
  "dailyListHint": "A morning notification with what's due today",
  "dailyListTime": "Time",
  "dailyListChannelName": "Daily list",
  "dailyListChannelDescription": "Once a day: what's due today and overdue",
  "dailyListToday": "{count, plural, =1{1 task today} other{{count} tasks today}}",
  "@dailyListToday": {"placeholders": {"count": {"type": "int"}}},
  "dailyListOverdue": "{count, plural, =1{1 overdue task} other{{count} overdue tasks}}",
  "@dailyListOverdue": {"placeholders": {"count": {"type": "int"}}},
  "dailyListTodayOverdue": "{today} today · {overdue} overdue",
  "@dailyListTodayOverdue": {"placeholders": {"today": {"type": "int"}, "overdue": {"type": "int"}}},
  "dailyListMore": "+{count} more",
  "@dailyListMore": {"placeholders": {"count": {"type": "int"}}},
```

`app_de.arb`:

```json
  "dailyListTitle": "Tagesliste",
  "dailyListHint": "Eine Benachrichtigung am Morgen mit allem, was heute fällig ist",
  "dailyListTime": "Uhrzeit",
  "dailyListChannelName": "Tagesliste",
  "dailyListChannelDescription": "Einmal am Tag: was heute fällig und was überfällig ist",
  "dailyListToday": "{count, plural, =1{1 Aufgabe heute} other{{count} Aufgaben heute}}",
  "dailyListOverdue": "{count, plural, =1{1 überfällige Aufgabe} other{{count} überfällige Aufgaben}}",
  "dailyListTodayOverdue": "{today} heute · {overdue} überfällig",
  "dailyListMore": "+{count} weitere",
```

`app_it.arb`:

```json
  "dailyListTitle": "Lista del giorno",
  "dailyListHint": "Una notifica al mattino con ciò che scade oggi",
  "dailyListTime": "Orario",
  "dailyListChannelName": "Lista del giorno",
  "dailyListChannelDescription": "Una volta al giorno: cosa scade oggi e cosa è in ritardo",
  "dailyListToday": "{count, plural, =1{1 attività oggi} other{{count} attività oggi}}",
  "dailyListOverdue": "{count, plural, =1{1 attività in ritardo} other{{count} attività in ritardo}}",
  "dailyListTodayOverdue": "{today} oggi · {overdue} in ritardo",
  "dailyListMore": "+{count} altre",
```

Run `flutter gen-l10n`.

`daily_list_tile.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/features/settings/ui/settings_controller.dart';
import 'package:nemo/l10n/app_localizations.dart';

/// The daily list: on or off, and when. Only where reminders exist.
class DailyListTile extends ConsumerWidget {
  const DailyListTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(remindersSupportedProvider)) return const SizedBox.shrink();
    final l = L.of(context);
    final enabled = ref.watch(dailyListEnabledProvider);
    final minutes = ref.watch(dailyListMinutesProvider);
    final time = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          key: const Key('daily-list-switch'),
          secondary: const Icon(Icons.wb_sunny_outlined),
          title: Text(l.dailyListTitle),
          subtitle: Text(l.dailyListHint),
          value: enabled,
          onChanged: (value) async {
            // Like a task's reminder switch: no permission, no switch.
            if (value &&
                !await ref.read(reminderSchedulerProvider).ensurePermission()) {
              return;
            }
            await ref
                .read(dailyListEnabledProvider.notifier)
                .set(enabled: value);
          },
        ),
        ListTile(
          key: const Key('daily-list-time'),
          leading: const SizedBox(width: 24),
          title: Text(l.dailyListTime),
          trailing: Text(time.format(context)),
          enabled: enabled,
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: time,
            );
            if (picked == null) return;
            await ref
                .read(dailyListMinutesProvider.notifier)
                .set(picked.hour * 60 + picked.minute);
          },
        ),
      ],
    );
  }
}
```

`settings_screen.dart`: import it and place `const DailyListTile(),` directly after `SectionHeader(title: l.settingsTasks),`.

- [ ] **Step 4: Run** `flutter test --concurrency=2 test/features/settings` -- PASS (the whole directory, so the existing settings tests confirm nothing moved). `flutter analyze` -- clean.

- [ ] **Step 5: Commit**

```bash
git add app/lib app/test/features/settings/daily_list_tile_test.dart
git commit -m "feat(app): daily list switch and time in Settings

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Wiring -- providers, refresher, main and taps

**Files:**
- Modify: `app/lib/core/providers.dart` (`notificationsApiProvider`, `digestStringsProvider`, `notificationRouteProvider`)
- Create: `app/lib/features/daily_list/daily_list_providers.dart`
- Modify: `app/lib/main.dart`
- Modify: `app/lib/app.dart` (start the refresher; follow tapped routes)
- Modify: `CHANGELOG.md`, `README.md`
- Test: `app/test/features/daily_list/daily_list_providers_test.dart`

**Interfaces:**
- Consumes: everything above.
- Produces:
  ```dart
  final notificationsApiProvider = Provider<NotificationsApi?>((_) => null);
  final digestStringsProvider = Provider<DigestStrings?>((_) => null);
  /// A route asked for by a tapped notification; NemoApp goes there and clears it.
  final notificationRouteProvider = Provider<ValueNotifier<String?>>(...);
  final dailyDigestSchedulerProvider = Provider<DailyDigestScheduler>(...);
  final dailyListDebounceProvider = Provider<Duration>((_) => const Duration(seconds: 1));
  final dailyListRefresherProvider = Provider<void>(...);
  ```

- [ ] **Step 1: Failing test** -- `daily_list_providers_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/notifications/daily_digest_scheduler.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/features/daily_list/daily_list_providers.dart';
import 'package:nemo/features/lists/data/lists_repository.dart';
import 'package:nemo/features/settings/ui/settings_controller.dart';
import 'package:nemo/features/tasks/ui/tasks_providers.dart';

import '../../support/test_db.dart';

class CountingScheduler implements DailyDigestScheduler {
  int refreshes = 0;

  @override
  Future<void> refresh() async => refreshes++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late CountingScheduler scheduler;
  late String inbox;

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 30));

  setUp(() async {
    final db = testDatabase();
    addTearDown(db.close);
    inbox = (await ListsRepository(db, testClock(), sequentialIds('l'))
            .ensureInbox())
        .id;
    final boot = await AppBootstrap.load(db);
    scheduler = CountingScheduler();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        bootstrapProvider.overrideWithValue(boot),
        nowProvider.overrideWithValue(() => testNow),
        idGeneratorProvider.overrideWithValue(sequentialIds()),
        dailyDigestSchedulerProvider.overrideWithValue(scheduler),
        dailyListDebounceProvider.overrideWithValue(
          const Duration(milliseconds: 10),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(dailyListRefresherProvider);
    await settle();
  });

  test('refreshes once at start', () {
    expect(scheduler.refreshes, 1);
  });

  test('a write reschedules once', () async {
    final tasks = container.read(tasksRepositoryProvider);
    for (var i = 0; i < 5; i++) {
      await tasks.create(
        listId: inbox,
        title: 'T$i',
        dueAt: testNow.millisecondsSinceEpoch,
      );
    }
    await settle();
    expect(scheduler.refreshes, 2);
  });

  test('changing a setting reschedules', () async {
    await container.read(dailyListMinutesProvider.notifier).set(420);
    await settle();
    expect(scheduler.refreshes, 2);
    await container.read(dailyListEnabledProvider.notifier).set(enabled: true);
    await settle();
    expect(scheduler.refreshes, 3);
  });

  test('without a notifications api the scheduler is a no-op', () {
    final plain = ProviderContainer();
    addTearDown(plain.dispose);
    expect(
      plain.read(dailyDigestSchedulerProvider),
      isA<NoopDailyDigestScheduler>(),
    );
  });
}
```

- [ ] **Step 2: Run** `flutter test --concurrency=2 test/features/daily_list` -- fails to compile.

- [ ] **Step 3: Implement**

`providers.dart` (imports `notifications_api.dart`, `daily_digest_scheduler.dart`):

```dart
/// The notification plugin; null where there is none (web, tests).
final notificationsApiProvider = Provider<NotificationsApi?>((_) => null);

/// Daily list text from the device locale; set with the api in `main`.
final digestStringsProvider = Provider<DigestStrings?>((_) => null);

/// A route asked for by a tapped notification. `NemoApp` goes there and
/// clears it; `main` sets it before the first frame when a tap started the
/// app.
final notificationRouteProvider = Provider<ValueNotifier<String?>>((ref) {
  final route = ValueNotifier<String?>(null);
  ref.onDispose(route.dispose);
  return route;
});
```

`daily_list_providers.dart`:

```dart
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/notifications/daily_digest_scheduler.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/features/settings/ui/settings_controller.dart';
import 'package:nemo/features/tasks/ui/tasks_providers.dart';

final dailyDigestSchedulerProvider = Provider<DailyDigestScheduler>((ref) {
  final api = ref.watch(notificationsApiProvider);
  final strings = ref.watch(digestStringsProvider);
  if (api == null || strings == null) return const NoopDailyDigestScheduler();
  return AndroidDailyDigestScheduler(
    api,
    loadTasks: () => ref.read(tasksRepositoryProvider).watchOpenDated().first,
    settings: () => DailyListSettings(
      enabled: ref.read(dailyListEnabledProvider),
      minutes: ref.read(dailyListMinutesProvider),
    ),
    strings: strings,
    now: ref.watch(nowProvider),
  );
});

/// How long the refresher waits for a burst of writes (a sync, an import)
/// to finish before rebuilding the week once.
final dailyListDebounceProvider = Provider<Duration>(
  (_) => const Duration(seconds: 1),
);

/// Keeps the scheduled daily lists in step with tasks, settings and the
/// date. Read once by `NemoApp`; lives as long as the app.
final dailyListRefresherProvider = Provider<void>((ref) {
  final scheduler = ref.watch(dailyDigestSchedulerProvider);
  final wait = ref.watch(dailyListDebounceProvider);
  Timer? pending;
  void schedule() {
    pending?.cancel();
    pending = Timer(wait, () => unawaited(scheduler.refresh()));
  }

  // Emits at once (the start), then on every change to an open dated task.
  final tasks = ref
      .watch(tasksRepositoryProvider)
      .watchOpenDated()
      .listen((_) => schedule());
  ref
    ..listen(dailyListEnabledProvider, (_, _) => schedule())
    ..listen(dailyListMinutesProvider, (_, _) => schedule());
  // The day may have rolled over while the app slept.
  final lifecycle = AppLifecycleListener(onResume: schedule);
  ref.onDispose(() {
    pending?.cancel();
    unawaited(tasks.cancel());
    lifecycle.dispose();
  });
});
```

`main.dart`: create the api once, share it, and route taps. Replace
`main`, `_prepare` and `_openReminders` with:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase.open();
  // Where a tapped notification asks to go; NemoApp follows it.
  final tapped = ValueNotifier<String?>(null);
  try {
    final boot = await _prepare(db, tapped).timeout(startupTimeout);
    final photoStore = await openPhotoStore();
    runApp(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          bootstrapProvider.overrideWithValue(boot.bootstrap),
          reminderSchedulerProvider.overrideWithValue(boot.notifications.reminders),
          notificationsApiProvider.overrideWithValue(boot.notifications.api),
          digestStringsProvider.overrideWithValue(
            boot.notifications.digestStrings,
          ),
          notificationRouteProvider.overrideWithValue(tapped),
          photoStoreProvider.overrideWithValue(photoStore),
        ],
        child: const NemoApp(),
      ),
    );
  } on Object catch (error) {
    // (keep the existing comment)
    // ignore: riverpod_lint/missing_provider_scope
    runApp(StartupErrorApp(error: error));
  }
}

typedef _Notifications = ({
  NotificationsApi? api,
  ReminderScheduler reminders,
  DigestStrings? digestStrings,
});

/// Everything that has to exist before the first frame.
Future<({AppBootstrap bootstrap, _Notifications notifications})> _prepare(
  AppDatabase db,
  ValueNotifier<String?> tapped,
) async {
  final boot = await AppBootstrap.load(db);
  // The Inbox exists before the first frame, so every screen can rely on it.
  await ListsRepository(
    db,
    HlcClock(node: boot.nodeId, last: boot.hlcLast),
    const Uuid().v4,
  ).ensureInbox();
  return (bootstrap: boot, notifications: await _openNotifications(tapped));
}

/// Local notifications on Android; nothing to schedule elsewhere.
///
/// A tap while the app runs lands in [tapped]; so does the tap that
/// started it, read once here.
Future<_Notifications> _openNotifications(ValueNotifier<String?> tapped) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return (
      api: null,
      reminders: const NoopReminderScheduler(),
      digestStrings: null,
    );
  }
  // Strings for the notification channels come from the device locale,
  // which is fixed for the life of a channel; the app locale may differ.
  final l = await L.delegate.load(
    WidgetsBinding.instance.platformDispatcher.locale,
  );
  final api = LocalNotificationsApi();
  await api.initialize(onTap: (payload) => tapped.value = payload);
  tapped.value = await api.launchPayload();
  return (
    api: api,
    reminders: AndroidReminderScheduler(
      api,
      channelName: l.remindersChannelName,
      channelDescription: l.remindersChannelDescription,
      body: l.remindersDueNow,
    ),
    digestStrings: DigestStrings(
      channelName: l.dailyListChannelName,
      channelDescription: l.dailyListChannelDescription,
      title: (today, overdue) => overdue == 0
          ? l.dailyListToday(today)
          : today == 0
          ? l.dailyListOverdue(overdue)
          : l.dailyListTodayOverdue(today, overdue),
      more: l.dailyListMore,
    ),
  );
}
```

Imports to add: `daily_digest_scheduler.dart`. `notificationRouteProvider`'s own
`ValueNotifier` is only the default for tests; the overridden one from `main`
lives for the process, so it is not disposed.

`app.dart`, `_NemoAppState`:

```dart
  late final ValueNotifier<String?> _tapped = ref.read(
    notificationRouteProvider,
  );

  void _followTap() {
    final route = _tapped.value;
    // Only app routes; a payload from anything else is ignored.
    if (route == null || !route.startsWith('/')) return;
    _tapped.value = null;
    _router.go(route);
  }
```

In `initState`, after `super.initState()`:

```dart
    _tapped.addListener(_followTap);
    ref.read(dailyListRefresherProvider);
```

and inside the existing post-frame callback, after `restore()` and the `mounted` check: `_followTap();` (a tap that started the app). In `dispose`, before `_router.dispose()`: `_tapped.removeListener(_followTap);`.

`CHANGELOG.md`, under `## Unreleased` (create the heading above `## 0.14.2` if absent), `### Added`:

```markdown
- A daily list: once a day, at a time you choose in Settings, the Android
  app shows one notification with what is due today and what is overdue,
  and opens Today when tapped. Days with nothing due stay quiet. Off until
  you turn it on.
```

`README.md`: in the features list, extend the reminders item: `…due dates with reminders, and a daily list each morning,…` (keep the sentence's rhythm).

- [ ] **Step 4: Run** `flutter test --concurrency=2 test/features/daily_list` -- PASS. Then the whole suite: `flutter test --concurrency=2` -- PASS. `flutter analyze` -- clean.

- [ ] **Step 5: Manual check on a device** (the executor cannot do this without an Android SDK; list it for the human): turn the daily list on at a time two minutes ahead with one task due today → one notification with its title; tap it → Today; tick the task off and set the time two minutes ahead again → no notification.

- [ ] **Step 6: Commit**

```bash
git add -A app/lib app/test CHANGELOG.md README.md
git commit -m "feat(app): send the daily list and open Today from it

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
