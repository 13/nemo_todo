import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/db/row_lookups.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/core/theme/app_style.dart';
import 'package:nemo/features/tasks/data/tasks_repository.dart';
import 'package:nemo/features/tasks/ui/task_selection.dart';
import 'package:nemo/router.dart';
import 'package:nemo/utils/dates.dart';
import 'package:nemo_core/nemo_core.dart';

import '../../support/pump_app.dart';
import '../../support/snack_bar.dart';
import '../../support/test_db.dart';

TasksRepository _repo(AppDatabase db, {String ids = 't'}) => TasksRepository(
  db,
  testClock('s'),
  sequentialIds(ids),
  reminders: const NoopReminderScheduler(),
  now: () => testNow,
);

/// Three open tasks due today, t1 to t3, the third repeating weekly, and
/// t4, done today: what Today lists. The first two are tagged errand.
Future<void> _seed(AppDatabase db, TaskList inbox) async {
  final tasks = _repo(db);
  for (final title in ['First', 'Second']) {
    await tasks.create(
      listId: inbox.id,
      title: title,
      dueAt: dayStartMs(testNow),
      tags: const ['errand'],
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

  appTest('a second tap on Done before the bar goes does nothing more', (
    tester,
  ) async {
    final app = await pumpApp(tester, seed: _seed);

    await _select(tester, ['Weekly']);
    final done = find.byKey(const Key('selection-done'));
    await tester.tap(done);
    await tester.tap(done);
    await tester.pumpAndSettle();

    final weekly = (await app.db.select(app.db.tasks).get())
        .where((t) => t.title == 'Weekly')
        .toList();
    expect(weekly, hasLength(2));
    expect(find.text('1 task done'), findsOneWidget);
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

  appTest('Move leaves alone a picked task deleted while the sheet is up', (
    tester,
  ) async {
    final app = await pumpApp(tester, seed: _seed);

    await _select(tester, ['First', 'Second']);
    await _tap(tester, find.byKey(const Key('selection-move')));
    // As another device's change would arrive through sync.
    await _repo(app.db).delete('t1');
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const Key('reschedule-tomorrow')));

    final first = await _task(app, 't1');
    expect(first.deletedAt, isNotNull);
    expect(first.dueAt, dayStartMs(testNow));
    expect((await _task(app, 't2')).dueAt, dayStartMsFrom(testNow, 1));
    expect(find.text('Moved 1 task to Tomorrow.'), findsOneWidget);

    await _tap(tester, find.text('Undo'));
    expect((await _task(app, 't1')).deletedAt, isNotNull);
    expect((await _task(app, 't2')).dueAt, dayStartMs(testNow));
  });

  appTest('Move keeps what changed elsewhere while the sheet was up', (
    tester,
  ) async {
    final app = await pumpApp(tester, seed: _seed);

    await _select(tester, ['First', 'Second']);
    await _tap(tester, find.byKey(const Key('selection-move')));
    final repo = _repo(app.db);
    await repo.save((await _task(app, 't2')).copyWith(title: 'Renamed'));
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const Key('reschedule-tomorrow')));

    expect((await _task(app, 't2')).title, 'Renamed');
    await _tap(tester, find.text('Undo'));
    expect((await _task(app, 't2')).title, 'Renamed');
    expect((await _task(app, 't2')).dueAt, dayStartMs(testNow));
  });

  appTest('Move keeps the time of day a task has', (tester) async {
    final app = await pumpApp(
      tester,
      seed: (db, inbox) async {
        await _seed(db, inbox);
        await _repo(db, ids: 'x').create(
          listId: inbox.id,
          title: 'Timed',
          dueAt: composeDue(testNow, hour: 15, minute: 0),
          dueHasTime: true,
        );
      },
    );

    await _select(tester, ['Timed', 'First']);
    await _tap(tester, find.byKey(const Key('selection-move')));
    await _tap(tester, find.byKey(const Key('reschedule-tomorrow')));

    final timed = await _task(app, 'x1');
    final tomorrow = DateTime.fromMillisecondsSinceEpoch(
      dayStartMsFrom(testNow, 1),
    );
    expect(timed.dueAt, composeDue(tomorrow, hour: 15, minute: 0));
    expect(timed.dueHasTime, isTrue);
    expect((await _task(app, 't1')).dueAt, tomorrow.millisecondsSinceEpoch);
  });

  appTest('a dismissed Move sheet leaves the selection as it was', (
    tester,
  ) async {
    final app = await pumpApp(tester, seed: _seed);

    await _select(tester, ['First', 'Second']);
    await _tap(tester, find.byKey(const Key('selection-move')));
    await tester.tapAt(const Offset(200, 20));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('reschedule-tomorrow')), findsNothing);
    expect(app.container.read(taskSelectionProvider), {'t1', 't2'});
    expect((await _task(app, 't1')).dueAt, dayStartMs(testNow));
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

  appTest('changing destination ends the selection', (tester) async {
    final app = await pumpApp(tester, seed: _seed);
    await _select(tester, ['First']);

    await _tap(tester, find.text('Upcoming'));
    expect(app.container.read(taskSelectionProvider), isNull);
    expect(find.byKey(const Key('select-tasks')), findsOneWidget);
  });

  appTest("a list's page selects too, and leaving it ends the selection", (
    tester,
  ) async {
    final app = await pumpApp(
      tester,
      initialLocation: Routes.lists,
      seed: _seed,
    );
    await _tap(tester, find.text('Inbox'));
    expect(find.byKey(const Key('select-tasks')), findsOneWidget);

    await _select(tester, ['First']);
    expect(app.container.read(taskSelectionProvider), {'t1'});
    await _tap(tester, find.byType(BackButton));
    expect(app.router.state.matchedLocation, Routes.lists);
    expect(app.container.read(taskSelectionProvider), isNull);
  });

  appTest("a page opened over Today does not take on Today's picks", (
    tester,
  ) async {
    final app = await pumpApp(tester, seed: _seed);
    await _select(tester, ['First']);

    unawaited(app.router.push(Routes.list(app.inbox.id)));
    await tester.pumpAndSettle();
    expect(app.container.read(taskSelectionProvider), isNull);
    expect(find.text('1 selected'), findsNothing);
    expect(find.byKey(const Key('select-tasks')), findsOneWidget);
  });

  appTest('picks made on a new page outlast the page it replaced', (
    tester,
  ) async {
    final app = await pumpApp(tester, seed: _seed);
    await _select(tester, ['First']);

    // Going straight to a list, as the macOS sidebar does: Today stays
    // until the new page has faded in, and goes after the picking began.
    app.router.go(Routes.list(app.inbox.id));
    await tester.pump();
    await tester.pump();
    app.container.read(taskSelectionProvider.notifier).toggle('t2');
    await tester.pumpAndSettle();
    expect(app.container.read(taskSelectionProvider), {'t2'});
  });

  for (final (name, location) in [
    ('a tag', Routes.tag('errand')),
    ('search', Routes.search),
  ]) {
    appTest('$name selects too', (tester) async {
      final app = await pumpApp(tester, initialLocation: location, seed: _seed);
      if (location == Routes.search) {
        await tester.enterText(find.byKey(const Key('search-field')), 'Fi');
        await tester.pumpAndSettle();
      }
      await _select(tester, ['First']);
      expect(app.container.read(taskSelectionProvider), {'t1'});
      expect(find.text('1 selected'), findsOneWidget);
      await _tap(tester, find.byKey(const Key('selection-done')));
      expect((await _task(app, 't1')).done, isTrue);
    });
  }

  appTest('in the Material style, Select comes first among the actions', (
    tester,
  ) async {
    await pumpApp(
      tester,
      initialLocation: Routes.upcoming,
      seed: (db, inbox) async {
        await KvStore(db).set(KvKeys.appStyle, AppStyle.material.name);
        await _seed(db, inbox);
      },
    );
    final select = tester.getCenter(find.byKey(const Key('select-tasks'))).dx;
    for (final other in ['Search', 'Settings']) {
      expect(select, lessThan(tester.getCenter(find.byTooltip(other)).dx));
    }
  });

  appTest('search offers Select only once there is something to find', (
    tester,
  ) async {
    final app = await pumpApp(
      tester,
      initialLocation: Routes.search,
      seed: _seed,
    );
    expect(find.byKey(const Key('select-tasks')), findsNothing);

    final field = find.byKey(const Key('search-field'));
    await tester.enterText(field, 'Fi');
    await tester.pumpAndSettle();
    await _select(tester, ['First']);
    expect(app.container.read(taskSelectionProvider), {'t1'});

    // Emptying the query takes the results, and the picks, away.
    await tester.enterText(field, '');
    await tester.pumpAndSettle();
    expect(app.container.read(taskSelectionProvider), isNull);
    expect(find.byKey(const Key('select-tasks')), findsNothing);
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
