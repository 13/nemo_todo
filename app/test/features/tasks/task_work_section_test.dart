import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/sync_writes.dart';

import '../../support/pump_app.dart';

void main() {
  testWidgets('the section stays out of the way until it holds something', (
    tester,
  ) async {
    final harness = await pumpApp(tester, initialLocation: '/tasks/t1');
    await harness.seedList('l1', 'Home');
    await harness.seedTask('t1', 'l1', title: 'Fix the tap');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('task-solution')), findsNothing);

    // The photo strip and the sections above push this one below the
    // fold, the same way the priority chips need scrolling to in the
    // existing task-detail tests.
    await scrollIntoView(tester, find.byKey(const Key('task-work-toggle')));
    await tester.tap(find.byKey(const Key('task-work-toggle')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('task-solution')), findsOneWidget);
  });

  testWidgets('what is typed is stored as minutes and minor units', (
    tester,
  ) async {
    final harness = await pumpApp(tester, initialLocation: '/tasks/t1');
    await harness.seedList('l1', 'Home');
    await harness.seedTask('t1', 'l1', title: 'Fix the tap');
    await tester.pumpAndSettle();
    await scrollIntoView(tester, find.byKey(const Key('task-work-toggle')));
    await tester.tap(find.byKey(const Key('task-work-toggle')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('task-solution')),
      'New washer, 12 mm',
    );
    await tester.enterText(find.byKey(const Key('task-time-spent')), '1h 30');
    await tester.enterText(find.byKey(const Key('task-cost')), '12.50');
    // The title field that the other task-detail tests tap to unfocus is
    // scrolled out of view up here, so this drops focus directly instead.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    final task = await harness.db.taskById('t1');
    expect(task!.solution, 'New washer, 12 mm');
    expect(task.timeSpentMinutes, 90);
    expect(task.costMinor, 1250);
  });

  testWidgets('a time it cannot read leaves the stored one alone', (
    tester,
  ) async {
    final harness = await pumpApp(tester, initialLocation: '/tasks/t1');
    await harness.seedList('l1', 'Home');
    await harness.seedTask('t1', 'l1', title: 'Fix the tap');
    await harness.db.upsertTask(
      (await harness.db.taskById('t1'))!.copyWith(timeSpentMinutes: 45),
    );
    await tester.pumpAndSettle();

    // Already expanded -- a recorded time counts as "holds something" --
    // but still below the fold, so the toggle is never tapped here.
    await scrollIntoView(tester, find.byKey(const Key('task-time-spent')));
    await tester.enterText(find.byKey(const Key('task-time-spent')), 'a while');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    expect((await harness.db.taskById('t1'))!.timeSpentMinutes, 45);
  });
}
