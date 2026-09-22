import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/features/tasks/ui/task_work_section.dart';
import 'package:nemo/features/tasks/ui/tasks_providers.dart';
import 'package:nemo/l10n/app_localizations.dart';

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

  // A real GoRouter pop happens to unfocus the outgoing page's fields on
  // its own -- each route's focus scope claims focus as it becomes current,
  // well before the popped route's state is actually disposed -- so it
  // never exercises the race this section's dispose is meant to guard
  // against. That race is specifically about a focused node being disposed
  // with no unfocus notification ever delivered, which needs the widget
  // removed from the tree in one frame, with nothing else claiming focus
  // first, to show up: the same shape the real task page's pop takes when
  // it is not wrapped in an animated route (e.g. the embedded pane on a
  // wide window swapping straight from one task's section to another's).
  // Swapping the provider scope's watched task away schedules a drift
  // stream-close timer the same way popping a route does; `appTest`
  // flushes it so the test binary does not hang after the assertion,
  // the same reason task_detail_screen_test.dart's own pop test uses it.
  appTest(
    'the section still saves what was typed if removed before it unfocuses',
    (tester) async {
      final harness = await pumpApp(tester);
      await harness.seedList('l1', 'Home');
      await harness.seedTask('t1', 'l1', title: 'Fix the tap');

      Widget host({required bool show}) => UncontrolledProviderScope(
        container: harness.container,
        child: MaterialApp(
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: Scaffold(
            body: show
                ? Consumer(
                    builder: (context, ref, _) {
                      final task = ref.watch(taskByIdProvider('t1')).value;
                      if (task == null) return const SizedBox.shrink();
                      return TaskWorkSection(
                        task: task,
                        save: harness.db.upsertTask,
                      );
                    },
                  )
                : const SizedBox.shrink(),
          ),
        ),
      );

      await tester.pumpWidget(host(show: true));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('task-work-toggle')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('task-solution')),
        'New washer, 12 mm',
      );
      // The field still holds focus -- no unfocus event has fired -- when
      // the widget is torn out of the tree in this single pumpWidget call.
      await tester.pumpWidget(host(show: false));

      final task = await harness.db.taskById('t1');
      expect(task!.solution, 'New washer, 12 mm');
    },
  );

  testWidgets(
    'a refused edit shows the stored value again, not the rejected text',
    (tester) async {
      final harness = await pumpApp(tester, initialLocation: '/tasks/t1');
      await harness.seedList('l1', 'Home');
      await harness.seedTask('t1', 'l1', title: 'Fix the tap');
      await harness.db.upsertTask(
        (await harness.db.taskById('t1'))!.copyWith(timeSpentMinutes: 45),
      );
      await tester.pumpAndSettle();

      await scrollIntoView(tester, find.byKey(const Key('task-time-spent')));
      await tester.enterText(
        find.byKey(const Key('task-time-spent')),
        'a while',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      expect((await harness.db.taskById('t1'))!.timeSpentMinutes, 45);
      expect(find.text('a while'), findsNothing);
      expect(find.text('45'), findsOneWidget);
    },
  );
}
