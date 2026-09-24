import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/features/tasks/data/tasks_repository.dart';
import 'package:nemo/router.dart';
import 'package:nemo/utils/dates.dart';

import '../../support/pump_app.dart';
import '../../support/test_db.dart';

/// Three tasks due today, with celebrations on unless [kv] says otherwise.
Future<TestApp> pumpToday(
  WidgetTester tester, {
  Map<String, String> kv = const {},
}) => pumpApp(
  tester,
  celebrate: true,
  seed: (db, inbox) async {
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
    for (final title in ['First', 'Second', 'Third']) {
      await tasks.create(
        listId: inbox.id,
        title: title,
        dueAt: dayStartMs(testNow),
      );
    }
  },
);

/// Confetti keeps frames coming, so pump a fixed while, not until settled.
Future<void> pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

Future<bool> isDone(TestApp app, String title) async =>
    (await app.db.select(app.db.tasks).get())
        .singleWhere((t) => t.title == title)
        .done;

void main() {
  appTest('a swipe completion celebrates like a tap', (tester) async {
    final app = await pumpToday(tester);

    await tester.drag(find.text('First'), const Offset(500, 0));
    await pumpFrames(tester);

    expect(await isDone(app, 'First'), isTrue);
    expect(find.byKey(const Key('achievement-banner')), findsOneWidget);
    expect(find.text('First step'), findsOneWidget);
  });

  appTest('undo after leaving the screen still reopens the task', (
    tester,
  ) async {
    final app = await pumpToday(tester);
    // One swipe only: every swipe queues its own SnackBar, and the Undo on
    // screen would otherwise belong to an earlier one.
    await tester.drag(find.text('Second'), const Offset(500, 0));
    await pumpFrames(tester);
    expect(await isDone(app, 'Second'), isTrue);
    expect(find.text('Task completed'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pump();

    // The SnackBar lives in the app's messenger and outlasts the list.
    app.router.go(Routes.settings);
    await pumpFrames(tester);
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await pumpFrames(tester);

    expect(tester.takeException(), isNull);
    expect(await isDone(app, 'Second'), isFalse);
    expect(find.byKey(const Key('achievement-banner')), findsNothing);
  });

  appTest('a swipe completion says its message in the snackbar', (
    tester,
  ) async {
    final app = await pumpToday(tester);
    // The first completion unlocks an achievement; the second is ordinary.
    await tester.drag(find.text('First'), const Offset(500, 0));
    await pumpFrames(tester);
    await tester.tap(find.byTooltip('Close'));
    await tester.pump();
    // Let the first snackbar go, so the one on screen is the second's.
    ScaffoldMessenger.of(tester.element(find.text('Second')))
        .removeCurrentSnackBar();
    await pumpFrames(tester);

    await tester.drag(find.text('Second'), const Offset(500, 0));
    await pumpFrames(tester);

    expect(await isDone(app, 'Second'), isTrue);
    final snack = find.byType(SnackBar);
    expect(snack, findsOneWidget);
    final text = tester
        .widget<Text>(
          find
              .descendant(
                of: find.byType(SnackBar),
                matching: find.byType(Text),
              )
              .first,
        )
        .data;
    expect(text, isNot('Task completed'));
    expect(text, isNotEmpty);
    expect(find.text('Undo'), findsOneWidget);
    expect(find.byKey(const Key('motivation-pill')), findsNothing);
  });

  appTest('with celebrations off a swipe says "Task completed"', (
    tester,
  ) async {
    final app = await pumpToday(tester, kv: {KvKeys.celebrations: 'false'});
    await tester.drag(find.text('First'), const Offset(500, 0));
    await pumpFrames(tester);
    ScaffoldMessenger.of(tester.element(find.text('Second')))
        .removeCurrentSnackBar();
    await pumpFrames(tester);

    await tester.drag(find.text('Second'), const Offset(500, 0));
    await pumpFrames(tester);

    expect(await isDone(app, 'Second'), isTrue);
    expect(find.text('Task completed'), findsOneWidget);
    expect(find.byKey(const Key('motivation-pill')), findsNothing);
  });
}
