import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/features/tasks/data/tasks_repository.dart';
import 'package:nemo/router.dart';
import 'package:nemo/utils/dates.dart';

import '../../support/pump_app.dart';
import '../../support/test_db.dart';

void main() {
  appTest('groups by day for a week then Later', (tester) async {
    await pumpApp(
      tester,
      initialLocation: Routes.upcoming,
      seed: (db, inbox) async {
        final repo = TasksRepository(
          db,
          testClock('s'),
          sequentialIds('t'),
          reminders: const NoopReminderScheduler(),
          now: () => testNow,
        );
        await repo.create(
          listId: inbox.id,
          title: 'Tomorrow task',
          dueAt: dayStartMsFrom(testNow, 1),
        );
        await repo.create(
          listId: inbox.id,
          title: 'Next week task',
          dueAt: dayStartMsFrom(testNow, 3),
        );
        await repo.create(
          listId: inbox.id,
          title: 'Far away',
          dueAt: dayStartMsFrom(testNow, 30),
        );
        await repo.create(listId: inbox.id, title: 'No date');
      },
    );
    expect(find.text('Tomorrow'), findsWidgets);
    expect(find.text('Tomorrow task'), findsOneWidget);
    expect(find.text('Next week task'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
    expect(find.text('Far away'), findsOneWidget);
    expect(find.text('No date'), findsNothing);
  });

  appTest('day headers name the right date across a clock change', (
    tester,
  ) async {
    // 25 October 2026 lasts 25 hours in Europe; run with TZ=Europe/Berlin.
    final sunday = DateTime(2026, 10, 25, 12);
    await pumpApp(
      tester,
      initialLocation: Routes.upcoming,
      now: sunday,
      seed: (db, inbox) async {
        await TasksRepository(
          db,
          testClock('s'),
          sequentialIds('t'),
          reminders: const NoopReminderScheduler(),
          now: () => sunday,
        ).create(
          listId: inbox.id,
          title: 'Tuesday task',
          dueAt: DateTime(2026, 10, 27).millisecondsSinceEpoch,
        );
      },
    );
    expect(find.text('Tuesday task'), findsOneWidget);
    expect(find.text('Tue, Oct 27'), findsOneWidget);
  });

  appTest('empty state and quick add defaults to tomorrow', (tester) async {
    final app = await pumpApp(tester, initialLocation: Routes.upcoming);
    expect(find.textContaining('No upcoming tasks'), findsOneWidget);
    await quickAdd(tester, 'Soon');
    expect(find.text('Soon'), findsOneWidget);
    expect(
      (await app.db.select(app.db.tasks).get()).single.dueAt,
      dayStartMsFrom(testNow, 1),
    );
  });
}
