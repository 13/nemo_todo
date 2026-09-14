import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/features/tasks/data/tasks_repository.dart';
import 'package:nemo/router.dart';

import '../../support/pump_app.dart';
import '../../support/test_db.dart';

void main() {
  Future<TestApp> pumpList(WidgetTester tester, List<String> titles) async {
    late String listId;
    final app = await pumpApp(
      tester,
      seed: (db, inbox) async {
        listId = inbox.id;
        final repo = TasksRepository(
          db,
          testClock('s'),
          sequentialIds('t'),
          reminders: const NoopReminderScheduler(),
          now: () => testNow,
        );
        for (final title in titles) {
          await repo.create(listId: inbox.id, title: title);
        }
      },
    );
    app.router.go(Routes.list(listId));
    await tester.pumpAndSettle();
    return app;
  }

  Future<List<String>> titlesInOrder(TestApp app) async {
    final rows = await app.db.select(app.db.tasks).get();
    rows.sort((a, b) => a.sortKey.compareTo(b.sortKey));
    return [for (final t in rows) t.title];
  }

  appTest('swiping right completes a task, and undo reopens it', (
    tester,
  ) async {
    final app = await pumpList(tester, ['Call the plumber']);

    await tester.drag(find.text('Call the plumber'), const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Task completed'), findsOneWidget);
    expect((await app.db.select(app.db.tasks).get()).single.done, isTrue);
    expect(find.text('1 completed'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect((await app.db.select(app.db.tasks).get()).single.done, isFalse);
    expect(find.text('Call the plumber'), findsOneWidget);
  });

  appTest('long-press and drag moves a task within its list', (tester) async {
    final app = await pumpList(tester, ['First', 'Second', 'Third']);
    expect(await titlesInOrder(app), ['First', 'Second', 'Third']);

    final from = tester.getCenter(find.text('First'));
    final to = tester.getBottomLeft(find.byType(Dismissible).at(2));
    final gesture = await tester.startGesture(from);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    // In steps, the way a finger moves: the list reshuffles as the dragged
    // row passes each neighbour's midpoint.
    const steps = 10;
    for (var i = 0; i < steps; i++) {
      await gesture.moveBy(Offset(0, (to.dy - from.dy) / steps));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(await titlesInOrder(app), ['Second', 'Third', 'First']);
  });
}
