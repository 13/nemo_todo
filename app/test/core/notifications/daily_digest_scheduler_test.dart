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

  // Calendar date `now` + [days], matching `_day` in the scheduler: id of
  // the [days]th scheduled morning has to be computed from its own date,
  // not from its position among the mornings.
  DateTime dayOf(DateTime from, int days) =>
      DateTime(from.year, from.month, from.day + days);

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
    final first = api.scheduled[dailyDigestId(dayOf(now, 0))]!;
    expect(first.at, DateTime(2026, 9, 28, 8).millisecondsSinceEpoch);
    expect(first.title, '1/0');
    expect(first.body, 'Dentist');
    expect(first.lines, ['Dentist']);
    expect(first.channelId, dailyDigestChannelId);
    expect(first.payload, '/today');
    // Every later morning sees Dentist as overdue.
    for (var i = 1; i < dailyDigestDays; i++) {
      expect(api.scheduled[dailyDigestId(dayOf(now, i))]!.title, '0/1');
    }
  });

  test('time passed today starts tomorrow', () async {
    now = DateTime(2026, 9, 28, 9);
    await scheduler().refresh();
    expect(
      api.scheduled[dailyDigestId(dayOf(now, 1))]!.at,
      DateTime(2026, 9, 29, 8).millisecondsSinceEpoch,
    );
  });

  test('empty mornings are skipped', () async {
    tasks = [task('Friday', DateTime(2026, 10, 2, 9))];
    await scheduler().refresh();
    // 28, 29, 30 Sep and 1 Oct have nothing; 2 Oct onwards do.
    expect(api.scheduled.keys.toSet(), {
      dailyDigestId(dayOf(now, 4)),
      dailyDigestId(dayOf(now, 5)),
      dailyDigestId(dayOf(now, 6)),
    });
  });

  test('off cancels all eight and schedules none', () async {
    await scheduler().refresh();
    settings = const DailyListSettings(enabled: false, minutes: 480);
    await scheduler().refresh();
    expect(api.scheduled, isEmpty);
    for (var i = 0; i < dailyDigestSlots; i++) {
      expect(api.cancelled, contains(dailyDigestId(dayOf(now, i))));
    }
  });

  test('adds a "more" line past six titles', () async {
    tasks = [for (var i = 0; i < 8; i++) task('T$i', DateTime(2026, 9, 28, 9))];
    await scheduler().refresh();
    final lines = api.scheduled[dailyDigestId(dayOf(now, 0))]!.lines!;
    expect(lines, hasLength(7));
    expect(lines.last, '+2 more');
  });

  test(
    "a refresh after the time has passed leaves today's notification alone",
    () async {
      // 07:00: today's morning (08:00) is still ahead, so it gets scheduled
      // along with the next six.
      now = DateTime(2026, 9, 28, 7);
      await scheduler().refresh();
      final todayId = dailyDigestId(dayOf(now, 0));
      final todayBefore = api.scheduled[todayId];
      expect(todayBefore, isNotNull);
      final cancelledBeforeSecondRefresh = List<int>.of(api.cancelled);

      // 09:00, same calendar day: today's time has passed. A second
      // refresh must not touch today's id at all -- not cancel it (which
      // would also pull an already-showing notification down) and not
      // reschedule it.
      now = DateTime(2026, 9, 28, 9);
      await scheduler().refresh();

      expect(
        api.cancelled.skip(cancelledBeforeSecondRefresh.length),
        isNot(contains(todayId)),
      );
      expect(api.scheduled[todayId], todayBefore);

      // Tomorrow through the following six mornings are (re)scheduled.
      for (var i = 1; i <= dailyDigestDays; i++) {
        expect(api.scheduled[dailyDigestId(dayOf(now, i))], isNotNull);
      }
    },
  );

  test("switching off cancels today's too", () async {
    // Today's morning already fired and is showing; the time has passed.
    now = DateTime(2026, 9, 28, 7);
    await scheduler().refresh();
    final todayId = dailyDigestId(dayOf(now, 0));
    now = DateTime(2026, 9, 28, 9);

    settings = const DailyListSettings(enabled: false, minutes: 480);
    await scheduler().refresh();

    expect(api.cancelled, contains(todayId));
    expect(api.scheduled, isEmpty);
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
  }, tags: 'dst');

  test('ids are negative and distinct across 8 consecutive days, including '
      'across the DST change', () {
    // 22-29 Oct 2026 straddles the 25 Oct clock change.
    final start = DateTime(2026, 10, 22);
    final ids = [
      for (var i = 0; i < dailyDigestSlots; i++) dailyDigestId(dayOf(start, i)),
    ];
    expect(ids.toSet(), hasLength(dailyDigestSlots));
    expect(ids, everyElement(lessThan(0)));
  }, tags: 'dst');

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
