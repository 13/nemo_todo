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

    await tester.enterText(
      find.byKey(const Key('task-tag-field')),
      'Home Stuff',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect((await app.db.taskById('t1'))!.tags, ['home-stuff']);
    expect(find.byKey(const Key('tag-home-stuff')), findsOneWidget);

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
