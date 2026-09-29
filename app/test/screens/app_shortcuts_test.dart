import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/features/tasks/data/tasks_repository.dart';
import 'package:nemo/features/tasks/ui/selected_task.dart';
import 'package:nemo/router.dart';
import 'package:nemo/utils/dates.dart';
import 'package:nemo_core/nemo_core.dart';

import '../support/pump_app.dart';
import '../support/test_db.dart';

/// Two tasks due today, in the Inbox: what Today lists.
Future<void> _seed(AppDatabase db, TaskList inbox) async {
  final tasks = TasksRepository(
    db,
    testClock('s'),
    sequentialIds('t'),
    reminders: const NoopReminderScheduler(),
    now: () => testNow,
  );
  for (final title in ['First errand', 'Second errand']) {
    await tasks.create(
      listId: inbox.id,
      title: title,
      dueAt: composeDue(testNow, hour: 15),
    );
  }
}

const _wide = Size(1400, 900);

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

void main() {
  appTest('right-clicking a task offers what a swipe does', (tester) async {
    final app = await pumpApp(tester, seed: _seed);
    await tester.tap(find.text('First errand'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(find.text('Move to…'), findsOneWidget);
    await tester.tap(find.text('Mark as done'));
    await tester.pumpAndSettle();
    final first = (await app.db.select(app.db.tasks).get()).firstWhere(
      (t) => t.title == 'First errand',
    );
    expect(first.done, isTrue);

    await tester.tap(find.text('Second errand'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Task deleted'), findsOneWidget);
    expect(find.text('Second errand'), findsNothing);
  });

  appTest('right-clicking a list opens its menu there', (tester) async {
    final app = await pumpApp(tester, initialLocation: Routes.lists);
    await app.seedList('work', 'Work');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Work'), buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    // A menu at the pointer, not the sheet a long press brings up.
    expect(find.byType(PopupMenuItem<String>), findsNWidgets(3));
    expect(find.byType(BottomSheet), findsNothing);
  });

  appTest('the arrow keys and space work through the list', (tester) async {
    final app = await pumpApp(tester, size: _wide, seed: _seed);
    String? selected() => app.container.read(selectedTaskProvider);

    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(selected(), 't1');
    expect(find.byKey(const Key('selected-task-t1')), findsOneWidget);
    await _press(tester, LogicalKeyboardKey.keyJ);
    expect(selected(), 't2');
    // The last stays the last.
    await _press(tester, LogicalKeyboardKey.arrowDown);
    expect(selected(), 't2');
    await _press(tester, LogicalKeyboardKey.keyK);
    expect(selected(), 't1');

    await _press(tester, LogicalKeyboardKey.space);
    final t1 = await (app.db.select(
      app.db.tasks,
    )..where((t) => t.id.equals('t1'))).getSingle();
    expect(t1.done, isTrue);

    await _press(tester, LogicalKeyboardKey.escape);
    expect(selected(), isNull);
  });

  appTest('digits change destination and N starts a task', (tester) async {
    final app = await pumpApp(tester, size: _wide);
    await _press(tester, LogicalKeyboardKey.digit3);
    expect(app.router.state.matchedLocation, Routes.lists);
    await _press(tester, LogicalKeyboardKey.digit1);
    expect(app.router.state.matchedLocation, Routes.today);

    await _press(tester, LogicalKeyboardKey.keyN);
    final field = tester.widget<TextField>(
      find.byKey(const Key('quick-add-field')),
    );
    expect(field.focusNode!.hasFocus, isTrue);

    // Now typing: a digit is text, not a destination.
    await tester.sendKeyEvent(LogicalKeyboardKey.digit3);
    await tester.pumpAndSettle();
    expect(app.router.state.matchedLocation, Routes.today);
  });

  appTest('the question mark lists the shortcuts', (tester) async {
    await pumpApp(tester, size: _wide);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.slash);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(find.text('Keyboard shortcuts'), findsOneWidget);
    expect(find.text('Previous or next task'), findsOneWidget);
  });
}
