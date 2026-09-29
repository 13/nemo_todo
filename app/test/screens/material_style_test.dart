import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/core/theme/app_style.dart';
import 'package:nemo/core/theme/app_theme.dart';
import 'package:nemo/features/tasks/data/tasks_repository.dart';
import 'package:nemo/router.dart';
import 'package:nemo/utils/dates.dart';
import 'package:nemo_core/nemo_core.dart';

import '../support/pump_app.dart';
import '../support/test_db.dart';

Future<void> _material(AppDatabase db, TaskList inbox) async {
  await KvStore(db).set(KvKeys.appStyle, AppStyle.material.name);
  await TasksRepository(
    db,
    testClock('s'),
    sequentialIds('t'),
    reminders: const NoopReminderScheduler(),
    now: () => testNow,
  ).create(
    listId: inbox.id,
    title: 'Ring the plumber',
    dueAt: composeDue(testNow, hour: 15),
  );
}

void main() {
  appTest('a task is added from the button, in a sheet', (tester) async {
    final app = await pumpApp(tester, seed: _material);
    // No field at the foot of the screen: Android adds from a button.
    expect(find.byKey(const Key('quick-add-field')), findsNothing);
    await tester.tap(find.byKey(const Key('new-task')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('new-task-sheet')), findsOneWidget);
    await quickAdd(tester, 'Water the plants');
    // The sheet closes once the task is in.
    expect(find.byKey(const Key('new-task-sheet')), findsNothing);
    final titles = (await app.db.select(app.db.tasks).get()).map(
      (t) => t.title,
    );
    expect(titles, contains('Water the plants'));
  });

  appTest('search is a bar at the top, not a destination', (tester) async {
    await pumpApp(tester, seed: _material);
    expect(find.byKey(const Key('search-bar')), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    await tester.tap(find.byKey(const Key('search-bar')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'plumb');
    // The results come from the database a moment after the typing.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('search-task-t1')), findsOneWidget);
  });

  appTest('a repeat is chosen from a sheet of options', (tester) async {
    final app = await pumpApp(
      tester,
      initialLocation: Routes.task('t1'),
      seed: _material,
    );
    await scrollIntoView(tester, find.byKey(const Key('task-repeat')));
    await tester.tap(find.byKey(const Key('task-repeat')));
    await tester.pumpAndSettle();
    expect(find.byType(RadioListTile<int>), findsWidgets);
    await tester.tap(find.text('Weekly'));
    await tester.pumpAndSettle();
    final task = await (app.db.select(
      app.db.tasks,
    )..where((t) => t.id.equals('t1'))).getSingle();
    expect(task.repeat, isNotNull);
  });

  test('back on Android follows the gesture', () {
    final theme = AppTheme.build(AppStyle.material, Brightness.light);
    expect(
      theme.pageTransitionsTheme.builders[TargetPlatform.android],
      isA<PredictiveBackPageTransitionsBuilder>(),
    );
  });
}
