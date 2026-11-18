import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/features/tasks/data/tasks_repository.dart';
import 'package:nemo/features/tasks/ui/selected_task.dart';
import 'package:nemo/features/tasks/ui/task_detail_screen.dart';
import 'package:nemo/features/tasks/ui/task_selection.dart';
import 'package:nemo/features/tasks/ui/tasks_providers.dart';
import 'package:nemo/router.dart';
import 'package:nemo/utils/dates.dart';
import 'package:nemo_core/nemo_core.dart';

import '../../support/pump_app.dart';
import '../../support/test_db.dart';

/// Three tasks due today, t1 to t3, in the Inbox: what Today lists.
Future<void> _seed(AppDatabase db, TaskList inbox) async {
  final tasks = TasksRepository(
    db,
    testClock('s'),
    sequentialIds('t'),
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
}

const _wide = Size(1400, 900);

/// Taps [finder] with [key] held down, as a click with a modifier.
Future<void> _tapWith(
  WidgetTester tester,
  LogicalKeyboardKey key,
  Finder finder,
) async {
  await tester.sendKeyDownEvent(key);
  await tester.tap(finder);
  await tester.sendKeyUpEvent(key);
  await tester.pumpAndSettle();
}

/// The custom actions a screen reader offers on [title]'s row.
List<String> _actions(WidgetTester tester, String title) {
  final node = find.semantics
      .byLabel(RegExp('^${RegExp.escape(title)}(\\. |\$)'))
      .evaluate()
      .single;
  return [
    for (final id
        in node.getSemanticsData().customSemanticsActionIds ?? const <int>[])
      CustomSemanticsAction.getAction(id)!.label ?? '',
  ];
}

void main() {
  appTest('while selecting, a tap picks the task instead of opening it', (
    tester,
  ) async {
    final app = await pumpApp(tester, seed: _seed);
    app.container.read(taskSelectionProvider.notifier).start();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('select-task-t1')), findsOneWidget);

    await tester.tap(find.text('First'));
    await tester.pumpAndSettle();

    expect(app.container.read(taskSelectionProvider), {'t1'});
    expect(find.byType(TaskDetailScreen), findsNothing);
    // The ring is quiet; the row, whose tap picks it, says it is picked.
    expect(
      tester.getSemantics(find.byKey(const Key('select-task-t1'))),
      isSemantics(isButton: true, hasCheckedState: true, isChecked: true),
    );
    expect(
      tester.getSemantics(find.byKey(const Key('select-task-t2'))),
      isSemantics(isButton: true, hasCheckedState: true, isChecked: false),
    );

    // A second tap drops it again.
    await tester.tap(find.text('First'));
    await tester.pumpAndSettle();
    expect(app.container.read(taskSelectionProvider), <String>{});
  });

  appTest('while selecting, a swipe does not complete the task', (
    tester,
  ) async {
    final app = await pumpApp(tester, seed: _seed);
    app.container.read(taskSelectionProvider.notifier).start();
    await tester.pumpAndSettle();

    await tester.drag(find.text('First'), const Offset(500, 0));
    await tester.pumpAndSettle();

    final first = (await app.db.select(app.db.tasks).get()).singleWhere(
      (t) => t.title == 'First',
    );
    expect(first.done, isFalse);
    expect(find.text('Task completed'), findsNothing);
  });

  appTest('ctrl-click starts selecting, shift-click extends the range', (
    tester,
  ) async {
    final app = await pumpApp(tester, size: _wide, seed: _seed);

    await _tapWith(tester, LogicalKeyboardKey.controlLeft, find.text('First'));
    expect(app.container.read(taskSelectionProvider), {'t1'});
    expect(app.container.read(selectedTaskProvider), isNull);

    await _tapWith(tester, LogicalKeyboardKey.shiftLeft, find.text('Third'));
    expect(app.container.read(taskSelectionProvider), {'t1', 't2', 't3'});
    expect(app.container.read(selectedTaskProvider), isNull);
  });

  appTest('while selecting, the open task looks chosen only if picked', (
    tester,
  ) async {
    final app = await pumpApp(tester, size: _wide, seed: _seed);
    await tester.tap(find.text('First'));
    await tester.pumpAndSettle();
    expect(app.container.read(selectedTaskProvider), 't1');
    Color openRow() => tester
        .widget<Material>(find.byKey(const Key('selected-task-t1')))
        .color!;
    expect(openRow(), isNot(Colors.transparent));

    await _tapWith(tester, LogicalKeyboardKey.controlLeft, find.text('Second'));

    expect(app.container.read(taskSelectionProvider), {'t2'});
    expect(app.container.read(selectedTaskProvider), 't1');
    expect(openRow(), Colors.transparent);
    final picked = tester.widget<Material>(
      find
          .ancestor(of: find.text('Second'), matching: find.byType(Material))
          .first,
    );
    expect(picked.color, isNot(Colors.transparent));
  });

  appTest('not selecting, a plain tap still opens the task', (tester) async {
    final app = await pumpApp(tester, seed: _seed);

    await tester.tap(find.text('First'));
    await tester.pumpAndSettle();

    expect(find.byType(TaskDetailScreen), findsOneWidget);
    expect(app.container.read(taskSelectionProvider), isNull);
    expect(find.byKey(const Key('select-task-t1')), findsNothing);
  });

  appTest('a picked task that leaves the list leaves the selection', (
    tester,
  ) async {
    final app = await pumpApp(tester, seed: _seed);
    final selection = app.container.read(taskSelectionProvider.notifier)
      ..start();
    await tester.pumpAndSettle();
    await tester.tap(find.text('First'));
    await tester.tap(find.text('Second'));
    await tester.pumpAndSettle();
    expect(app.container.read(taskSelectionProvider), {'t1', 't2'});

    await app.container.read(tasksRepositoryProvider).delete('t1');
    await tester.pumpAndSettle();

    expect(app.container.read(taskSelectionProvider), {'t2'});
    selection.end();
  });

  appTest('while selecting, a screen reader cannot move a row either', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final app = await pumpApp(tester, seed: _seed);
    app.router.go(Routes.list(app.inbox.id));
    await tester.pumpAndSettle();
    expect(_actions(tester, 'Second'), containsAll(['Move up', 'Move down']));

    app.container.read(taskSelectionProvider.notifier).start();
    await tester.pumpAndSettle();

    expect(
      _actions(tester, 'Second'),
      isNot(anyOf(contains('Move up'), contains('Move down'))),
    );
    handle.dispose();
  });
}
