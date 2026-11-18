import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/db/row_lookups.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/core/theme/app_style.dart';
import 'package:nemo/features/tasks/data/tasks_repository.dart';
import 'package:nemo/features/tasks/ui/task_selection.dart';
import 'package:nemo/utils/dates.dart';
import 'package:nemo_core/nemo_core.dart';

import '../../support/pump_app.dart';
import '../../support/snack_bar.dart';
import '../../support/test_db.dart';

TasksRepository _repo(AppDatabase db) => TasksRepository(
  db,
  testClock('s'),
  sequentialIds('t'),
  reminders: const NoopReminderScheduler(),
  now: () => testNow,
);

/// Three open tasks due today, t1 to t3, the third repeating weekly, and
/// t4, done today: what Today lists.
Future<void> _seed(AppDatabase db, TaskList inbox) async {
  final tasks = _repo(db);
  for (final title in ['First', 'Second']) {
    await tasks.create(
      listId: inbox.id,
      title: title,
      dueAt: dayStartMs(testNow),
    );
  }
  await tasks.create(
    listId: inbox.id,
    title: 'Weekly',
    dueAt: dayStartMs(testNow),
    repeat: Repeats.weekly,
  );
  final finished = await tasks.create(
    listId: inbox.id,
    title: 'Finished',
    dueAt: dayStartMs(testNow),
  );
  await tasks.setDone(finished.id, done: true);
}

Future<Task> _task(TestApp app, String id) =>
    app.db.taskById(id).then((t) => t!);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Starts selecting from the top bar and picks [titles].
Future<void> _select(WidgetTester tester, List<String> titles) async {
  await _tap(tester, find.byKey(const Key('select-tasks')));
  for (final title in titles) {
    await _tap(tester, find.text(title));
  }
}

void main() {
  appTest('Done completes the picked tasks, and Undo reopens them', (
    tester,
  ) async {
    final app = await pumpApp(tester, seed: _seed);

    await _select(tester, ['First', 'Second']);
    expect(find.text('2 selected'), findsOneWidget);

    await _tap(tester, find.byKey(const Key('selection-done')));
    expect((await _task(app, 't1')).done, isTrue);
    expect((await _task(app, 't2')).done, isTrue);
    expect(find.text('2 tasks done'), findsOneWidget);
    expect(app.container.read(taskSelectionProvider), isNull);

    await _tap(tester, find.text('Undo'));
    expect((await _task(app, 't1')).done, isFalse);
    expect((await _task(app, 't2')).done, isFalse);
  });

  appTest('a repeating task done with others comes back as a new one', (
    tester,
  ) async {
    final app = await pumpApp(tester, seed: _seed);

    await _select(tester, ['First', 'Weekly']);
    await _tap(tester, find.byKey(const Key('selection-done')));

    final weekly = (await app.db.select(app.db.tasks).get())
        .where((t) => t.title == 'Weekly')
        .toList();
    expect(weekly, hasLength(2));
    expect(weekly.where((t) => t.done), hasLength(1));
    expect(weekly.where((t) => !t.done), hasLength(1));
  });

  appTest('Done leaves done ones done unless every picked one is done', (
    tester,
  ) async {
    final app = await pumpApp(tester, seed: _seed);
    await _tap(tester, find.text('1 completed'));

    await _select(tester, ['First', 'Finished']);
    await _tap(tester, find.byKey(const Key('selection-done')));
    expect((await _task(app, 't1')).done, isTrue);
    expect((await _task(app, 't4')).done, isTrue);
    // The first snackbar would sit over the bar.
    await expectSnackBarTimesOut(tester);

    await _select(tester, ['First', 'Finished']);
    // Every picked one is done, so the button undoes.
    expect(
      find.descendant(
        of: find.byKey(const Key('selection-done')),
        matching: find.byIcon(Icons.undo_rounded),
      ),
      findsOneWidget,
    );
    await _tap(tester, find.byKey(const Key('selection-done')));
    expect((await _task(app, 't1')).done, isFalse);
    expect((await _task(app, 't4')).done, isFalse);
    expect(find.text('2 tasks not done'), findsOneWidget);
  });

  appTest('Move puts the picked tasks on another day, and Undo back', (
    tester,
  ) async {
    final app = await pumpApp(tester, seed: _seed);

    await _select(tester, ['First', 'Second']);
    await _tap(tester, find.byKey(const Key('selection-move')));
    await _tap(tester, find.byKey(const Key('reschedule-tomorrow')));

    final tomorrow = dayStartMsFrom(testNow, 1);
    expect((await _task(app, 't1')).dueAt, tomorrow);
    expect((await _task(app, 't2')).dueAt, tomorrow);
    expect(find.text('Moved 2 tasks to Tomorrow.'), findsOneWidget);
    expect(app.container.read(taskSelectionProvider), isNull);

    await _tap(tester, find.text('Undo'));
    expect((await _task(app, 't1')).dueAt, dayStartMs(testNow));
    expect((await _task(app, 't2')).dueAt, dayStartMs(testNow));
  });

  appTest('Delete removes the picked tasks; Undo works from elsewhere', (
    tester,
  ) async {
    final app = await pumpApp(tester, seed: _seed);

    await _select(tester, ['First', 'Second']);
    await _tap(tester, find.byKey(const Key('selection-delete')));
    expect(find.text('2 tasks deleted'), findsOneWidget);
    expect((await _task(app, 't1')).deletedAt, isNotNull);
    expect((await _task(app, 't2')).deletedAt, isNotNull);

    // The Undo outlives the screen it was offered on.
    await _tap(tester, find.text('Upcoming'));
    await _tap(tester, find.text('Undo'));
    expect((await _task(app, 't1')).deletedAt, isNull);
    expect((await _task(app, 't2')).deletedAt, isNull);
  });

  appTest('a picked task deleted elsewhere drops out of the count', (
    tester,
  ) async {
    final app = await pumpApp(tester, seed: _seed);

    await _select(tester, ['First', 'Second']);
    expect(find.text('2 selected'), findsOneWidget);

    // As another device's change would arrive through sync.
    await _repo(app.db).delete('t1');
    await tester.pumpAndSettle();
    // The list drops the pick after the frame it rebuilt in.
    await tester.pump();

    expect(find.text('1 selected'), findsOneWidget);
  });

  appTest('Cancel ends selecting and brings the quick-add bar back', (
    tester,
  ) async {
    final app = await pumpApp(tester, seed: _seed);

    await _select(tester, ['First']);
    expect(find.byKey(const Key('quick-add-field')), findsNothing);

    await _tap(tester, find.byKey(const Key('selection-cancel')));
    expect(app.container.read(taskSelectionProvider), isNull);
    expect(find.byKey(const Key('quick-add-field')), findsOneWidget);
  });

  for (final style in AppStyle.values) {
    for (final wide in [false, true]) {
      final where = wide ? 'replaces the top bar' : 'takes the foot';
      appTest('in the ${style.name} style, on a '
          '${wide ? 'wide' : 'narrow'} window, the bar $where', (tester) async {
        await pumpApp(
          tester,
          size: wide ? const Size(1400, 900) : const Size(400, 800),
          seed: (db, inbox) async {
            await KvStore(db).set(KvKeys.appStyle, style.name);
            await _seed(db, inbox);
          },
        );
        // Material adds from a button, beside the rail on a wide window;
        // the others from the bar at the foot.
        final adding = find.byKey(
          Key(switch (style) {
            AppStyle.material when wide => 'rail-new-task',
            AppStyle.material => 'new-task',
            _ => 'quick-add-field',
          }),
        );
        expect(adding, findsOneWidget);

        await _select(tester, ['First']);

        expect(find.text('1 selected'), findsOneWidget);
        expect(find.byKey(const Key('selection-cancel')), findsOneWidget);
        // On a wide window the top bar, and its Select, make way; the foot
        // stays. On a narrow one the foot makes way.
        expect(
          find.byKey(const Key('select-tasks')),
          wide ? findsNothing : findsOneWidget,
        );
        expect(adding, wide ? findsOneWidget : findsNothing);
      });
    }
  }
}
