import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/features/lists/data/lists_repository.dart';
import 'package:nemo/features/tasks/data/tasks_repository.dart';
import 'package:nemo/router.dart';
import 'package:nemo/utils/dates.dart';

import '../../support/pump_app.dart';
import '../../support/snack_bar.dart';
import '../../support/test_db.dart';

void main() {
  TasksRepository repo(AppDatabase db) => TasksRepository(
    db,
    testClock('s'),
    sequentialIds('t'),
    reminders: const NoopReminderScheduler(),
    now: () => testNow,
  );

  appTest('a tag on a task opens every task with that tag', (tester) async {
    await pumpApp(
      tester,
      seed: (db, inbox) async {
        final work = await ListsRepository(
          db,
          testClock('seed'),
          sequentialIds('w'),
        ).create(name: 'Work');
        final tasks = repo(db);
        await tasks.create(
          listId: inbox.id,
          title: 'Milk',
          tags: ['shop'],
          dueAt: dayStartMs(testNow),
        );
        await tasks.create(
          listId: work.id,
          title: 'Printer paper',
          tags: ['shop'],
        );
        // Close, but not the same tag.
        await tasks.create(
          listId: work.id,
          title: 'Laptop',
          tags: ['shopping'],
        );
      },
    );

    await tester.tap(find.byKey(const Key('tile-tag-t1-shop')));
    await tester.pumpAndSettle();

    expect(find.text('#shop'), findsOneWidget);
    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('Printer paper'), findsOneWidget);
    expect(find.text('Laptop'), findsNothing);
  });

  appTest('an unused tag says there is nothing under it', (tester) async {
    await pumpApp(tester, initialLocation: Routes.tag('nothing'));
    expect(find.text('No tasks tagged #nothing.'), findsOneWidget);
  });

  appTest('a long press moves a task to tomorrow, and the snackbar goes', (
    tester,
  ) async {
    final app = await pumpApp(
      tester,
      seed: (db, inbox) async {
        await repo(db).create(
          listId: inbox.id,
          title: 'Call the bank',
          dueAt: dayStartMs(testNow),
        );
      },
    );

    await tester.longPress(find.text('Call the bank'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reschedule-tomorrow')));
    await tester.pumpAndSettle();

    expect((await app.db.taskById('t1'))!.dueAt, dayStartMsFrom(testNow, 1));
    expect(find.text('Moved to Tomorrow.'), findsOneWidget);
    expect(find.text('Call the bank'), findsNothing, reason: 'no longer today');
    // Undo is offered, not forced: left alone, the snackbar goes.
    await expectSnackBarTimesOut(tester);
    expect((await app.db.taskById('t1'))!.dueAt, dayStartMsFrom(testNow, 1));
  });

  appTest('undo on the reschedule snackbar puts the task back', (tester) async {
    final app = await pumpApp(
      tester,
      seed: (db, inbox) async {
        await repo(db).create(
          listId: inbox.id,
          title: 'Call the bank',
          dueAt: dayStartMs(testNow),
        );
      },
    );

    await tester.longPress(find.text('Call the bank'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reschedule-tomorrow')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect((await app.db.taskById('t1'))!.dueAt, dayStartMs(testNow));
    expect(find.text('Call the bank'), findsOneWidget);
  });

  appTest('clearing the date from the sheet turns the reminder off', (
    tester,
  ) async {
    final app = await pumpApp(
      tester,
      seed: (db, inbox) async {
        await repo(db).create(
          listId: inbox.id,
          title: 'Dentist',
          dueAt: dayStartMs(testNow),
          remind: true,
        );
      },
    );
    await tester.longPress(find.text('Dentist'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reschedule-clear')));
    await tester.pumpAndSettle();

    final task = (await app.db.taskById('t1'))!;
    expect(task.dueAt, isNull);
    expect(task.remind, isFalse);
    expect(find.text('Date cleared.'), findsOneWidget);
  });

  appTest('quick add reads the date, tags and priority out of the line', (
    tester,
  ) async {
    final app = await pumpApp(tester);
    await quickAdd(tester, 'Milk #shop !high tomorrow');

    final task = (await app.db.select(app.db.tasks).get()).single;
    expect(task.title, 'Milk');
    expect(task.tags, ['shop']);
    expect(task.priority, 3);
    // Overrides Today's own default of today.
    expect(task.dueAt, dayStartMsFrom(testNow, 1));
  });
}
