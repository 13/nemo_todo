import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/features/tasks/data/tasks_repository.dart';
import 'package:nemo/utils/dates.dart';
import 'package:nemo_core/nemo_core.dart';

import '../../support/pump_app.dart';
import '../../support/test_db.dart';

/// [now]'s day of the year, counted in calendar days, which picks the
/// line's variant.
int _dayOfYearOf(DateTime now) => DateTime.utc(
  now.year,
  now.month,
  now.day,
).difference(DateTime.utc(now.year)).inDays;

final int _dayOfYear = _dayOfYearOf(testNow);

Future<void> _seedDueToday(
  AppDatabase db,
  TaskList inbox,
  List<String> titles, {
  List<bool> done = const [],
  DateTime? now,
}) async {
  final today = now ?? testNow;
  final tasks = TasksRepository(
    db,
    testClock('seed'),
    sequentialIds('task'),
    reminders: const NoopReminderScheduler(),
    now: () => today,
  );
  for (var i = 0; i < titles.length; i++) {
    final t = await tasks.create(
      listId: inbox.id,
      title: titles[i],
      dueAt: dayStartMs(today),
    );
    if (i < done.length && done[i]) await tasks.setDone(t.id, done: true);
  }
}

/// A task completed [daysAgo] calendar days before [testNow], written
/// straight to the database so a completion date in the past is possible
/// (the repository's own `setDone` always stamps "now"). Left undated, so
/// it never shows up in Today's own list of open or completed-today tasks.
Future<void> _seedCompletedDaysAgo(
  AppDatabase db,
  TaskList inbox,
  int daysAgo,
) {
  final at = DateTime(testNow.year, testNow.month, testNow.day - daysAgo, 9);
  return db.upsertTask(
    Task(
      id: 'old',
      listId: inbox.id,
      title: 'Long done',
      sortKey: 'a',
      updatedAt: testClock('seed').now().toString(),
      done: true,
      doneAt: at.millisecondsSinceEpoch,
    ),
  );
}

void main() {
  appTest('no tasks due today: no progress header', (tester) async {
    await pumpApp(tester, celebrate: true);
    expect(find.byKey(const Key('today-progress')), findsNothing);
  });

  appTest('some done: bar and count, no line', (tester) async {
    await pumpApp(
      tester,
      celebrate: true,
      seed: (db, inbox) =>
          _seedDueToday(db, inbox, ['A', 'B', 'C'], done: [true, false, false]),
    );
    expect(find.byKey(const Key('today-progress')), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byKey(const Key('today-progress-bar')),
    );
    expect(bar.value, 1 / 3);
    expect(find.text('1 of 3 done'), findsOneWidget);
    expect(find.byKey(const Key('today-progress-line')), findsNothing);
  });

  appTest('none done, last completion yesterday: a fresh-start line', (
    tester,
  ) async {
    await pumpApp(
      tester,
      celebrate: true,
      seed: (db, inbox) async {
        await _seedDueToday(db, inbox, ['A', 'B', 'C']);
        await _seedCompletedDaysAgo(db, inbox, 1);
      },
    );
    expect(find.text('0 of 3 done'), findsOneWidget);
    const freshStart = [
      'A fresh start.',
      'Pick one to begin.',
      'One thing at a time.',
    ];
    expect(
      find.text(freshStart[_dayOfYear % freshStart.length]),
      findsOneWidget,
    );
  });

  // The night after Europe's clocks went forward on 29 March 2026: counted
  // in hours, the day since New Year is an hour short of a whole one.
  appTest('the line is picked by calendar day across a clock change', (
    tester,
  ) async {
    final now = DateTime(2026, 3, 30, 0, 30);
    await pumpApp(
      tester,
      celebrate: true,
      now: now,
      seed: (db, inbox) => _seedDueToday(db, inbox, ['A', 'B'], now: now),
    );
    expect(_dayOfYearOf(now), 88);
    const freshStart = [
      'A fresh start.',
      'Pick one to begin.',
      'One thing at a time.',
    ];
    expect(find.text(freshStart[88 % freshStart.length]), findsOneWidget);
  }, tags: 'dst');

  appTest('none done today, last completion 4 days ago: a welcome-back line', (
    tester,
  ) async {
    await pumpApp(
      tester,
      celebrate: true,
      seed: (db, inbox) async {
        await _seedDueToday(db, inbox, ['A', 'B', 'C']);
        await _seedCompletedDaysAgo(db, inbox, 4);
      },
    );
    expect(find.text('0 of 3 done'), findsOneWidget);
    const welcomeBack = [
      'Welcome back. One small thing is a good start.',
      'Good to see you. Start with something easy.',
    ];
    expect(
      find.text(welcomeBack[_dayOfYear % welcomeBack.length]),
      findsOneWidget,
    );
  });

  appTest('all done: the all-clear line', (tester) async {
    await pumpApp(
      tester,
      celebrate: true,
      seed: (db, inbox) =>
          _seedDueToday(db, inbox, ['A', 'B'], done: [true, true]),
    );
    expect(find.text('2 of 2 done'), findsOneWidget);
    expect(find.text('All clear. Enjoy the rest of your day.'), findsOneWidget);
  });

  appTest('celebrations off: bar and count shown, no line', (tester) async {
    await pumpApp(
      tester,
      // pumpApp defaults celebrations off; explicit here for clarity.
      seed: (db, inbox) => _seedDueToday(db, inbox, ['A', 'B']),
    );
    expect(find.byKey(const Key('today-progress')), findsOneWidget);
    expect(find.text('0 of 2 done'), findsOneWidget);
    expect(find.byKey(const Key('today-progress-line')), findsNothing);
  });
}
