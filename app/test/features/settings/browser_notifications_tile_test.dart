import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/core/notifications/browser_notifications.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/core/notifications/timed_notifications.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/router.dart';
import 'package:nemo_core/nemo_core.dart';

import '../../support/fake_browser_notifications.dart';
import '../../support/pump_app.dart';
import '../../support/test_db.dart';

/// The web's reminder scheduler, as `main` builds it, over a fake browser.
class _BrowserScheduler implements ReminderScheduler {
  _BrowserScheduler(this.browser);
  final FakeBrowser browser;

  @override
  Future<bool> ensurePermission() =>
      TimedNotifications(browser).requestPermission();

  @override
  Future<void> sync(Task task) async {}

  @override
  Future<void> cancel(String taskId) async {}
}

void main() {
  List<Object> web(FakeBrowser? browser) => [
    remindersInPageProvider.overrideWithValue(true),
    browserNotificationsProvider.overrideWithValue(browser),
    if (browser != null)
      reminderSchedulerProvider.overrideWithValue(_BrowserScheduler(browser))
    else
      // Tests run as Android, which has reminders; the web without
      // notifications has none.
      remindersSupportedProvider.overrideWithValue(false),
  ];

  const tile = Key('browser-notifications');
  const allow = Key('browser-notifications-allow');

  group('Settings', () {
    appTest('not on Android', (tester) async {
      await pumpApp(
        tester,
        initialLocation: Routes.settings,
        overrides: [remindersInPageProvider.overrideWithValue(false)],
      );
      expect(find.byKey(tile), findsNothing);
    });

    appTest('asks from its Allow button, then says it is on', (tester) async {
      final browser = FakeBrowser(permission: BrowserPermission.ask);
      await pumpApp(
        tester,
        initialLocation: Routes.settings,
        overrides: web(browser),
      );
      await scrollIntoView(tester, find.byKey(tile));
      expect(
        find.text(
          'Reminders and the daily list arrive only while a nemo tab is '
          'open. Allow notifications to get them.',
        ),
        findsOneWidget,
      );
      // Nothing is asked until the button is pressed.
      expect(browser.requests, 0);
      await tester.tap(find.byKey(allow));
      await tester.pumpAndSettle();
      expect(browser.requests, 1);
      expect(find.byKey(allow), findsNothing);
      expect(
        find.text(
          'On. Reminders and the daily list arrive only while a nemo tab '
          'is open.',
        ),
        findsOneWidget,
      );
      // With a browser that notifies, the daily list is offered too.
      expect(find.byKey(const Key('daily-list-switch')), findsOneWidget);
    });

    appTest('says when the browser blocks it, with no button', (tester) async {
      await pumpApp(
        tester,
        initialLocation: Routes.settings,
        overrides: web(FakeBrowser(permission: BrowserPermission.denied)),
      );
      await scrollIntoView(tester, find.byKey(tile));
      expect(find.textContaining('Blocked by the browser.'), findsOneWidget);
      expect(find.byKey(allow), findsNothing);
    });

    appTest('says when the browser has no notifications', (tester) async {
      await pumpApp(
        tester,
        initialLocation: Routes.settings,
        overrides: web(null),
      );
      await scrollIntoView(tester, find.byKey(tile));
      expect(
        find.textContaining('This browser cannot show notifications'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('daily-list-switch')), findsNothing);
    });
  });

  group("a task's Remind switch", () {
    Future<void> seed(AppDatabase db, TaskList inbox) => db.upsertTask(
      Task(
        id: 't1',
        listId: inbox.id,
        title: 'Dentist',
        sortKey: 'V',
        dueAt: testNow.add(const Duration(hours: 2)).millisecondsSinceEpoch,
        dueHasTime: true,
        updatedAt: testClock('a').now().toString(),
      ),
    );

    final remind = find.byKey(const Key('task-remind'));

    appTest('asks the browser when switched on', (tester) async {
      final browser = FakeBrowser(permission: BrowserPermission.ask);
      final app = await pumpApp(
        tester,
        initialLocation: Routes.task('t1'),
        overrides: web(browser),
        seed: seed,
      );
      await scrollIntoView(tester, remind);
      await tester.tap(remind);
      await tester.pumpAndSettle();
      expect(browser.requests, 1);
      expect((await app.db.taskById('t1'))!.remind, isTrue);
    });

    appTest('says the browser blocks notifications', (tester) async {
      final browser = FakeBrowser(permission: BrowserPermission.denied);
      final app = await pumpApp(
        tester,
        initialLocation: Routes.task('t1'),
        overrides: web(browser),
        seed: seed,
      );
      await scrollIntoView(tester, remind);
      expect(
        find.text('Notifications are blocked in this browser.'),
        findsOneWidget,
      );
      await tester.tap(remind);
      await tester.pumpAndSettle();
      expect((await app.db.taskById('t1'))!.remind, isFalse);
      // Allowed in the browser's settings and back in the tab.
      browser.current = BrowserPermission.granted;
      await tester.pumpAndSettle();
      expect(
        find.text('Notifications are blocked in this browser.'),
        findsNothing,
      );
    });
  });
}
