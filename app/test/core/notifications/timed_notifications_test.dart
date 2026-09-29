import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/notifications/browser_notifications.dart';
import 'package:nemo/core/notifications/timed_notifications.dart';

import '../../support/fake_browser_notifications.dart';

void main() {
  final start = DateTime(2026, 9, 29, 10);
  late FakeTimeline time;
  late FakeBrowser browser;
  late FiredLog log;
  late TimedNotifications api;

  TimedNotifications open() => TimedNotifications(
    browser,
    fired: log,
    now: () => time.now,
    startTimer: time.start,
  );

  setUp(() {
    time = FakeTimeline(start);
    browser = FakeBrowser()..now = () => time.now;
    log = MemoryFiredLog();
    api = open();
  });

  Future<void> schedule(
    int id,
    DateTime at, {
    String title = 'Dentist',
    List<String>? lines,
    String? payload,
    TimedNotifications? on,
  }) => (on ?? api).scheduleAt(
    id: id,
    title: title,
    body: 'Due now',
    epochMs: at.millisecondsSinceEpoch,
    channelName: 'Reminders',
    channelDescription: 'desc',
    lines: lines,
    payload: payload,
  );

  test('shows a notification at its time, not before', () async {
    await schedule(1, start.add(const Duration(minutes: 30)));
    time.advance(const Duration(minutes: 29));
    expect(browser.shown, isEmpty);
    time.advance(const Duration(minutes: 1));
    expect(browser.shown.single.tag, TimedNotifications.tagFor(1));
    expect(browser.shown.single.title, 'Dentist');
    expect(browser.shown.single.body, 'Due now');
    expect(browser.shown.single.at, start.add(const Duration(minutes: 30)));
    expect(time.pending, isEmpty);
  });

  test('several are shown in order, each at its own time', () async {
    await schedule(2, start.add(const Duration(minutes: 20)), title: 'B');
    await schedule(1, start.add(const Duration(minutes: 10)), title: 'A');
    time.advance(const Duration(hours: 1));
    expect([for (final s in browser.shown) s.title], ['A', 'B']);
    expect(browser.shown[1].at, start.add(const Duration(minutes: 20)));
  });

  test('scheduling an id again replaces it', () async {
    await schedule(1, start.add(const Duration(minutes: 10)), title: 'Old');
    await schedule(1, start.add(const Duration(minutes: 20)), title: 'New');
    time.advance(const Duration(minutes: 15));
    expect(browser.shown, isEmpty);
    time.advance(const Duration(minutes: 5));
    expect(browser.shown.single.title, 'New');
  });

  test('cancelling drops it and closes one already shown', () async {
    await schedule(1, start.add(const Duration(minutes: 10)));
    await api.cancel(1);
    time.advance(const Duration(hours: 1));
    expect(browser.shown, isEmpty);
    expect(browser.closed, [TimedNotifications.tagFor(1)]);
    expect(time.pending, isEmpty);
  });

  test('a far-off time is waited for an hour at a time', () async {
    await schedule(1, start.add(const Duration(days: 40)));
    expect(time.pending, [TimedNotifications.maxWait]);
    time.advance(const Duration(hours: 1));
    expect(time.pending, [TimedNotifications.maxWait]);
    time.advance(const Duration(days: 40));
    expect(browser.shown, hasLength(1));
    expect(browser.shown.single.at, start.add(const Duration(days: 40)));
  });

  group('missed while no tab was open', () {
    test('a few minutes late it shows at once', () async {
      await schedule(1, start.subtract(const Duration(minutes: 3)));
      expect(browser.shown.single.at, start);
    });

    test('just inside the window it still shows', () async {
      await schedule(1, start.subtract(TimedNotifications.missedWindow));
      expect(browser.shown, hasLength(1));
    });

    test('older than the window it is dropped', () async {
      await schedule(
        1,
        start.subtract(
          TimedNotifications.missedWindow + const Duration(minutes: 1),
        ),
      );
      expect(browser.shown, isEmpty);
      expect(time.pending, isEmpty);
    });

    test('a timer that fires late after sleep follows the same rule', () async {
      await schedule(1, start.add(const Duration(minutes: 5)), title: 'Soon');
      await schedule(2, start.add(const Duration(minutes: 50)), title: 'Late');
      time.sleep(const Duration(minutes: 55));
      // Both came due during the sleep: the one 50 minutes late is stale,
      // the one 5 minutes late is not.
      expect([for (final s in browser.shown) s.title], ['Late']);
    });
  });

  group('shown once', () {
    test('a reload does not show it again', () async {
      await schedule(1, start.subtract(const Duration(minutes: 2)));
      expect(browser.shown, hasLength(1));
      // The page loads again and the scheduler asks for the same one.
      final reloaded = open();
      await schedule(
        1,
        start.subtract(const Duration(minutes: 2)),
        on: reloaded,
      );
      expect(browser.shown, hasLength(1));
    });

    test('a second tab sharing the log does not show it again', () async {
      final other = open();
      final at = start.add(const Duration(minutes: 1));
      await schedule(1, at);
      await schedule(1, at, on: other);
      time.advance(const Duration(minutes: 1));
      expect(browser.shown, hasLength(1));
    });

    test('moved to a new time, it shows again', () async {
      await schedule(1, start.subtract(const Duration(minutes: 2)));
      await schedule(1, start.add(const Duration(minutes: 5)));
      time.advance(const Duration(minutes: 5));
      expect(browser.shown, hasLength(2));
    });

    test('an unreadable log counts as empty', () async {
      log.write('not json');
      await schedule(1, start);
      expect(browser.shown, hasLength(1));
      log.write('[1, 2]');
      await schedule(2, start);
      expect(browser.shown, hasLength(2));
    });

    test('entries older than a day are forgotten', () async {
      await schedule(1, start);
      time.advance(const Duration(days: 2));
      await schedule(2, time.now);
      expect(log.read(), isNot(contains('1@')));
      expect(log.read(), contains('2@'));
    });
  });

  test('nothing is shown without permission', () async {
    browser.current = BrowserPermission.ask;
    await schedule(1, start.add(const Duration(minutes: 1)));
    time.advance(const Duration(minutes: 1));
    expect(browser.shown, isEmpty);
    // Nor later, once allowed: that moment has passed.
    browser.current = BrowserPermission.granted;
    time.advance(const Duration(minutes: 1));
    expect(browser.shown, isEmpty);
  });

  test('permission is asked of the browser', () async {
    browser.current = BrowserPermission.ask;
    expect(await api.requestPermission(), isTrue);
    browser
      ..current = BrowserPermission.ask
      ..answer = BrowserPermission.denied;
    expect(await api.requestPermission(), isFalse);
    expect(browser.requests, 2);
  });

  test('a click hands the payload to the tap handler', () async {
    final taps = <String?>[];
    await api.initialize(onTap: taps.add);
    await schedule(1, start, payload: '/tasks/t1');
    browser.click(TimedNotifications.tagFor(1));
    expect(taps, ['/tasks/t1']);
    expect(await api.launchPayload(), isNull);
  });

  test('lines become the body, one per line', () async {
    await schedule(-1, start, lines: ['A', 'B', '+2 more']);
    expect(browser.shown.single.body, 'A\nB\n+2 more');
  });
}
