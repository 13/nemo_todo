import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/features/tasks/data/tasks_repository.dart';
import 'package:nemo/router.dart';
import 'package:nemo_core/nemo_core.dart';

import '../../support/pump_app.dart';
import '../../support/test_db.dart';

void main() {
  Future<void> seed(AppDatabase db, TaskList inbox) async {
    await TasksRepository(
      db,
      testClock('s'),
      sequentialIds('t'),
      reminders: const NoopReminderScheduler(),
      now: () => testNow,
    ).create(listId: inbox.id, title: 'Draft', notes: 'first');
  }

  appTest('edits title and notes with debounce, priority, tags, subtasks', (
    tester,
  ) async {
    final app = await pumpApp(
      tester,
      initialLocation: Routes.task('t1'),
      seed: seed,
    );
    expect(find.text('Draft'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('task-title')), 'Final');
    await tester.enterText(find.byKey(const Key('task-notes')), 'second');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    var task = await app.db.taskById('t1');
    expect(task!.title, 'Final');
    expect(task.notes, 'second');

    await tester.tap(find.text('High'));
    await tester.pumpAndSettle();
    expect((await app.db.taskById('t1'))!.priority, 3);

    // The repeat row made the screen taller than the viewport, so the
    // fields below it are not built until they are scrolled to.
    await tester.scrollUntilVisible(
      find.byKey(const Key('task-tag-field')),
      200,
      // The subtask list is a scrollable of its own, so the one to drive
      // has to be named rather than guessed at.
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('task-tag-field')),
      'Home Stuff',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect((await app.db.taskById('t1'))!.tags, ['home-stuff']);
    expect(find.byKey(const Key('tag-home-stuff')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('task-subtask-field')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('task-subtask-field')),
      'Step one',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('Step one'), findsOneWidget);
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    task = await app.db.taskById('t1');
    final subs = await app.db.select(app.db.subtasks).get();
    expect(subs.single.done, isTrue);

    expect(
      find.byKey(const Key('task-clear-date')),
      findsNothing,
      reason: 'the clear action only exists once a date is set',
    );
  });

  appTest('a repeat rule waits for a due date, then sticks', (tester) async {
    final app = await pumpApp(
      tester,
      initialLocation: Routes.task('t1'),
      seed: (db, inbox) async {
        await TasksRepository(
          db,
          testClock('s'),
          sequentialIds('t'),
          reminders: const NoopReminderScheduler(),
          now: () => testNow,
        ).create(
          listId: inbox.id,
          title: 'Bins',
          dueAt: testNow.add(const Duration(days: 1)).millisecondsSinceEpoch,
        );
      },
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('task-repeat')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('repeat-weekly')));
    await tester.pumpAndSettle();
    expect((await app.db.taskById('t1'))!.repeat, 'weekly');

    await tester.tap(find.byKey(const Key('repeat-never')));
    await tester.pumpAndSettle();
    expect((await app.db.taskById('t1'))!.repeat, isNull);
  });

  appTest('the richer repeat rules are offered and stick', (tester) async {
    final app = await pumpApp(
      tester,
      initialLocation: Routes.task('t1'),
      seed: (db, inbox) async {
        await TasksRepository(
          db,
          testClock('s'),
          sequentialIds('t'),
          reminders: const NoopReminderScheduler(),
          now: () => testNow,
        ).create(
          listId: inbox.id,
          title: 'Bins',
          // A Friday, so the month rule names one.
          dueAt: DateTime(2026, 9, 11, 8).millisecondsSinceEpoch,
        );
      },
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('task-repeat')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Weekdays'), findsOneWidget);
    expect(find.text('Every 2 weeks'), findsOneWidget);
    // Named after the day the task is due on, not a fixed weekday.
    expect(find.text('Last Friday of the month'), findsOneWidget);

    await tester.tap(find.byKey(const Key('repeat-every-2w')));
    await tester.pumpAndSettle();
    expect((await app.db.taskById('t1'))!.repeat, 'every:2w');

    await tester.tap(find.byKey(const Key('repeat-weekdays')));
    await tester.pumpAndSettle();
    expect((await app.db.taskById('t1'))!.repeat, 'weekdays');

    await tester.tap(find.byKey(const Key('repeat-monthly-last-fri')));
    await tester.pumpAndSettle();
    expect((await app.db.taskById('t1'))!.repeat, 'monthly:last-fri');
  });

  appTest('a rule this version cannot read is shown, not hidden', (
    tester,
  ) async {
    await pumpApp(
      tester,
      initialLocation: Routes.task('t1'),
      seed: (db, inbox) async {
        final clock = testClock('s');
        await db.upsertTask(
          Task(
            id: 't1',
            listId: inbox.id,
            title: 'From a newer app',
            sortKey: 'V',
            dueAt: DateTime(2026, 9, 11, 8).millisecondsSinceEpoch,
            repeat: 'every:3rd-thursday-of-quarter',
            updatedAt: clock.now().toString(),
          ),
        );
      },
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('task-repeat')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    // Saying "Never" here would be a lie about a task that does repeat.
    expect(find.byKey(const Key('repeat-unreadable')), findsOneWidget);
    expect(find.text('every:3rd-thursday-of-quarter'), findsOneWidget);
  });

  appTest('without a due date the repeat row says why it is off', (
    tester,
  ) async {
    await pumpApp(tester, initialLocation: Routes.task('t1'), seed: seed);
    await tester.scrollUntilVisible(
      find.byKey(const Key('task-repeat')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('needs a due date'), findsOneWidget);
    expect(
      tester
          .widget<ChoiceChip>(find.byKey(const Key('repeat-weekly')))
          .onSelected,
      isNull,
    );
  });

  appTest('delete asks, tombstones and pops', (tester) async {
    final app = await pumpApp(
      tester,
      initialLocation: Routes.task('t1'),
      seed: seed,
    );
    await tester.tap(find.byKey(const Key('task-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm-delete-task')));
    await tester.pumpAndSettle();
    expect((await app.db.taskById('t1'))!.isDeleted, isTrue);
    expect(find.byKey(const Key('task-title')), findsNothing);
  });

  appTest('unknown task shows a message', (tester) async {
    await pumpApp(tester, initialLocation: Routes.task('nope'));
    expect(find.text('This task no longer exists.'), findsOneWidget);
  });
}
