import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/core/widgets/task_tile.dart';
import 'package:nemo/features/tasks/data/tasks_repository.dart';
import 'package:nemo/utils/dates.dart';

import '../../support/pump_app.dart';
import '../../support/test_db.dart';

void main() {
  appTest('starts empty, quick-add creates a task due today', (tester) async {
    final app = await pumpApp(tester);
    expect(find.text('Nothing due today. Enjoy the calm.'), findsOneWidget);
    await quickAdd(tester, 'Water the plants');
    expect(find.text('Water the plants'), findsOneWidget);
    expect(find.text('Today'), findsWidgets);
    final task = (await app.db.select(app.db.tasks).get()).single;
    expect(task.dueAt, dayStartMs(testNow));
    expect(task.listId, app.inbox.id);
    expect(await app.db.outboxCount(), 2, reason: 'inbox + task queued');
  });

  appTest('checking a task moves it into the completed section', (
    tester,
  ) async {
    await pumpApp(
      tester,
      seed: (db, inbox) async {
        final repo = TasksRepository(
          db,
          testClock('s'),
          sequentialIds('t'),
          reminders: const NoopReminderScheduler(),
          now: () => testNow,
        );
        await repo.create(
          listId: inbox.id,
          title: 'Overdue one',
          dueAt: dayStartMsFrom(testNow, -2),
        );
        await repo.create(
          listId: inbox.id,
          title: 'Due now',
          dueAt: dayStartMs(testNow),
        );
      },
    );
    expect(find.text('Overdue'), findsOneWidget);
    expect(find.text('2 days ago'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(InkWell, 'Due now'),
        matching: find.byType(DoneCheck),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 completed'), findsOneWidget);
    expect(find.text('Due now'), findsNothing, reason: 'collapsed by default');
    await tester.tap(find.text('1 completed'));
    await tester.pumpAndSettle();
    expect(find.text('Due now'), findsOneWidget);
  });

  appTest('swiping left deletes with undo', (tester) async {
    final app = await pumpApp(tester);
    await quickAdd(tester, 'Temporary');
    await tester.drag(find.text('Temporary'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Task deleted'), findsOneWidget);
    expect((await app.db.select(app.db.tasks).get()).single.isDeleted, isTrue);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect((await app.db.select(app.db.tasks).get()).single.isDeleted, isFalse);
    expect(find.text('Temporary'), findsOneWidget);
  });

  appTest('tapping a task opens its detail page', (tester) async {
    await pumpApp(tester);
    await quickAdd(tester, 'Open me');
    await tester.tap(find.text('Open me'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('task-title')), findsOneWidget);
    expect(find.byKey(const Key('task-priority')), findsOneWidget);
  });
}
