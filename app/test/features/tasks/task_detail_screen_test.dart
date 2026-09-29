import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/features/tasks/data/tasks_repository.dart';
import 'package:nemo/features/tasks/ui/tasks_providers.dart';
import 'package:nemo/router.dart';
import 'package:nemo_core/nemo_core.dart';

import '../../support/pump_app.dart';
import '../../support/snack_bar.dart';
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

    // The photo strip made the screen taller than the viewport, so the
    // priority row -- already built, this `ListView` is not lazy -- sits
    // out of the fold until scrolled to. `ensureVisible` does nothing for
    // a widget that is built but below the fold, so this uses the same
    // hit-testable scroll the tap-heavy tests elsewhere on this branch do.
    await scrollIntoView(tester, find.text('High'));
    await tester.pumpAndSettle();
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

  appTest('a custom rule is built in the dialog and named on its chip', (
    tester,
  ) async {
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
          // The second Friday of September.
          dueAt: DateTime(2026, 9, 11, 8).millisecondsSinceEpoch,
        );
      },
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('repeat-custom')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Custom…'), findsOneWidget);

    await tester.tap(find.byKey(const Key('repeat-custom')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('repeat-interval')), '3');
    await tester.pumpAndSettle();
    expect(find.text('Every 3 days'), findsOneWidget, reason: 'the preview');
    await tester.tap(find.byKey(const Key('repeat-custom-save')));
    await tester.pumpAndSettle();
    expect((await app.db.taskById('t1'))!.repeat, 'every:3d');
    expect(
      find.descendant(
        of: find.byKey(const Key('repeat-custom')),
        matching: find.text('Every 3 days'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('repeat-custom')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('repeat-mode-weekday')));
    await tester.pumpAndSettle();
    // Guessed from the due date rather than starting from nothing.
    expect(find.text('Second Friday of the month'), findsOneWidget);
    await tester.tap(find.byKey(const Key('repeat-custom-save')));
    await tester.pumpAndSettle();
    expect((await app.db.taskById('t1'))!.repeat, 'monthly:2nd-fri');

    // Blanking the interval leaves nothing to save.
    await tester.tap(find.byKey(const Key('repeat-custom')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('repeat-mode-interval')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('repeat-interval')), '');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('repeat-custom-save')))
          .onPressed,
      isNull,
    );
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
    await expectSnackBarTimesOut(tester);
  });

  group('a sync landing while the page is open', () {
    // Another device's edit, landing in the store the way a pull does:
    // behind the page's back, with a newer stamp than anything it wrote.
    Future<void> remoteEdit(TestApp app, {String? title, String? notes}) async {
      final stored = (await app.db.taskById('t1'))!;
      await app.container
          .read(tasksRepositoryProvider)
          .save(
            stored.copyWith(
              title: title ?? stored.title,
              notes: notes ?? stored.notes,
            ),
          );
    }

    TextField field(WidgetTester tester, String key) =>
        tester.widget<TextField>(find.byKey(Key(key)));

    for (final (key, isTitle) in [
      ('task-title', true),
      ('task-notes', false),
    ]) {
      final what = isTitle ? 'title' : 'notes';

      appTest('is not overwritten by a focused but unedited $what field on '
          'leaving', (tester) async {
        final app = await pumpApp(
          tester,
          initialLocation: Routes.task('t1'),
          seed: seed,
        );
        await tester.tap(find.byKey(Key(key)));
        await tester.pumpAndSettle();
        expect(field(tester, key).focusNode!.hasFocus, isTrue);

        await remoteEdit(
          app,
          title: isTitle ? 'Remote' : null,
          notes: isTitle ? null : 'remote',
        );
        await tester.pumpAndSettle();
        // Focused, so the field keeps what it showed rather than moving
        // the text out from under the cursor.
        expect(
          field(tester, key).controller!.text,
          isTitle ? 'Draft' : 'first',
        );

        app.router.go(Routes.today);
        await tester.pumpAndSettle();

        final task = (await app.db.taskById('t1'))!;
        expect(task.title, isTitle ? 'Remote' : 'Draft');
        expect(task.notes, isTitle ? 'first' : 'remote');
      });

      appTest('shows a sync once its focused, unedited $what field is '
          'left', (tester) async {
        final app = await pumpApp(
          tester,
          initialLocation: Routes.task('t1'),
          seed: seed,
        );
        await tester.tap(find.byKey(Key(key)));
        await tester.pumpAndSettle();

        await remoteEdit(
          app,
          title: isTitle ? 'Remote' : null,
          notes: isTitle ? null : 'remote',
        );
        await tester.pumpAndSettle();
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();

        expect(
          field(tester, key).controller!.text,
          isTitle ? 'Remote' : 'remote',
        );
        final task = (await app.db.taskById('t1'))!;
        expect(task.title, isTitle ? 'Remote' : 'Draft');
        expect(task.notes, isTitle ? 'first' : 'remote');
      });

      appTest('loses to typing in the $what field, the later edit', (
        tester,
      ) async {
        final app = await pumpApp(
          tester,
          initialLocation: Routes.task('t1'),
          seed: seed,
        );
        await tester.enterText(find.byKey(Key(key)), 'Mine');
        await remoteEdit(
          app,
          title: isTitle ? 'Remote' : null,
          notes: isTitle ? null : 'remote',
        );
        await tester.pumpAndSettle();
        expect(field(tester, key).controller!.text, 'Mine');

        app.router.go(Routes.today);
        await tester.pumpAndSettle();

        final task = (await app.db.taskById('t1'))!;
        expect(isTitle ? task.title : task.notes, 'Mine');
      });
    }

    appTest('an edit already saved is not written again over a sync that '
        'lands after it, while the field still has focus', (tester) async {
      final app = await pumpApp(
        tester,
        initialLocation: Routes.task('t1'),
        seed: seed,
      );
      await tester.enterText(find.byKey(const Key('task-title')), 'Mine');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect((await app.db.taskById('t1'))!.title, 'Mine');

      await remoteEdit(app, title: 'Remote');
      await tester.pumpAndSettle();
      app.router.go(Routes.today);
      await tester.pumpAndSettle();

      expect((await app.db.taskById('t1'))!.title, 'Remote');
    });

    appTest('refreshes an unfocused field in place', (tester) async {
      final app = await pumpApp(
        tester,
        initialLocation: Routes.task('t1'),
        seed: seed,
      );
      await remoteEdit(app, title: 'Remote', notes: 'remote');
      await tester.pumpAndSettle();
      expect(field(tester, 'task-title').controller!.text, 'Remote');
      expect(field(tester, 'task-notes').controller!.text, 'remote');
    });

    appTest("editing one field does not write the other one's stale text", (
      tester,
    ) async {
      final app = await pumpApp(
        tester,
        initialLocation: Routes.task('t1'),
        seed: seed,
      );
      await tester.tap(find.byKey(const Key('task-title')));
      await tester.pumpAndSettle();
      await remoteEdit(app, title: 'Remote', notes: 'remote');
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('task-notes')), 'mine');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      final task = (await app.db.taskById('t1'))!;
      expect(task.title, 'Remote');
      expect(task.notes, 'mine');
    });
  });

  appTest('unknown task shows a message', (tester) async {
    await pumpApp(tester, initialLocation: Routes.task('nope'));
    expect(find.text('This task no longer exists.'), findsOneWidget);
  });
}
