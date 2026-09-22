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

  testWidgets(
    'a refused edit shows the stored cost again, not the rejected text',
    (tester) async {
      final harness = await pumpApp(tester, initialLocation: '/tasks/t1');
      await harness.seedList('l1', 'Home');
      await harness.seedTask('t1', 'l1', title: 'Fix the tap');
      await harness.db.upsertTask(
        (await harness.db.taskById('t1'))!.copyWith(costMinor: 1250),
      );
      await tester.pumpAndSettle();

      await scrollIntoView(tester, find.byKey(const Key('task-cost')));
      expect(find.text('12.50'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('task-cost')), 'lots');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      expect((await harness.db.taskById('t1'))!.costMinor, 1250);
      expect(find.text('lots'), findsNothing);
      expect(find.text('12.50'), findsOneWidget);
    },
  );

  testWidgets('a stored cost renders as the locale would write it', (
    tester,
  ) async {
    final harness = await pumpApp(tester, initialLocation: '/tasks/t1');
    await harness.seedList('l1', 'Home');
    await harness.seedTask('t1', 'l1', title: 'Fix the tap');
    await harness.db.upsertTask(
      (await harness.db.taskById('t1'))!.copyWith(costMinor: 1250),
    );
    await tester.pumpAndSettle();

    await scrollIntoView(tester, find.byKey(const Key('task-cost')));

    expect(find.text('12.50'), findsOneWidget);
  });

  testWidgets(
    'a stored cost renders at full precision, not a double round-trip',
    (tester) async {
      // `(cost / 100).toStringAsFixed(2)` -- the expression this replaced
      // -- passes every other test in this file too, because 1250 / 100 is
      // exactly 12.50 in a double. It only disagrees with the integer
      // arithmetic at a value a double can no longer represent exactly;
      // 8999999999998001 is the same value work_input_test.dart pins on
      // the parse side (`parseMinorUnits('89999999999980.01')`), so this
      // pins the same amount on the display side. Against the old
      // expression this renders '89999999999980.02', not '...01'.
      final harness = await pumpApp(tester, initialLocation: '/tasks/t1');
      await harness.seedList('l1', 'Home');
      await harness.seedTask('t1', 'l1', title: 'Fix the tap');
      await harness.db.upsertTask(
        (await harness.db.taskById('t1'))!
            .copyWith(costMinor: 8999999999998001),
      );
      await tester.pumpAndSettle();

      await scrollIntoView(tester, find.byKey(const Key('task-cost')));

      expect(find.text('89999999999980.01'), findsOneWidget);
    },
  );

  testWidgets('a negative stored cost redisplays with the sign in the right '
      'place', (tester) async {
    // `~/` truncates toward zero but Dart's `%` never goes negative, so
    // splitting a negative cost straight into those two prints the wrong
    // amount (-1205 would print as "-12.95"). Not reachable by typing --
    // `parseMinorUnits` refuses a leading '-' -- but a peer's synced row
    // is free to write one, and a re-save should not scramble it further.
    final harness = await pumpApp(tester, initialLocation: '/tasks/t1');
    await harness.seedList('l1', 'Home');
    await harness.seedTask('t1', 'l1', title: 'Fix the tap');
    await harness.db.upsertTask(
      (await harness.db.taskById('t1'))!.copyWith(costMinor: -1205),
    );
    await tester.pumpAndSettle();

    await scrollIntoView(tester, find.byKey(const Key('task-cost')));

    expect(find.text('-12.05'), findsOneWidget);
  });
}
