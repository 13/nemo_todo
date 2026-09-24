import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/core/widgets/task_tile.dart';
import 'package:nemo/features/lists/data/lists_repository.dart';
import 'package:nemo/features/tasks/data/tasks_repository.dart';
import 'package:nemo/router.dart';
import 'package:nemo/utils/dates.dart';

import '../../support/pump_app.dart';
import '../../support/test_db.dart';

/// Taps a task's done check and lets the celebration confetti run its
/// course, as the celebration overlay tests do -- `pumpAndSettle` never
/// returns while it animates.
Future<void> tickOff(WidgetTester tester, String title) async {
  await tester.tap(
    find.descendant(
      of: find.widgetWithText(InkWell, title),
      matching: find.byType(DoneCheck),
    ),
  );
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

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
        // Undated: shown in the "No date" section now, not omitted, so its
        // title stays clear of that section header's own text.
        await repo.create(listId: inbox.id, title: 'Someday task');
      },
    );
    expect(find.text('Tomorrow'), findsWidgets);
    expect(find.text('Tomorrow task'), findsOneWidget);
    expect(find.text('Next week task'), findsOneWidget);
    expect(find.text('Later'), findsOneWidget);
    expect(find.text('Far away'), findsOneWidget);
    expect(find.text('No date'), findsOneWidget, reason: 'section header');
    expect(find.text('Someday task'), findsOneWidget);
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
  }, tags: 'dst');

  appTest('empty state and quick add defaults to tomorrow', (tester) async {
    final app = await pumpApp(tester, initialLocation: Routes.upcoming);
    expect(find.textContaining('Nothing planned'), findsOneWidget);
    await quickAdd(tester, 'Soon');
    expect(find.text('Soon'), findsOneWidget);
    expect(
      (await app.db.select(app.db.tasks).get()).single.dueAt,
      dayStartMsFrom(testNow, 1),
    );
  });

  appTest('a dated task and an undated task: No date section after dated', (
    tester,
  ) async {
    late String groceriesId;
    await pumpApp(
      tester,
      initialLocation: Routes.upcoming,
      seed: (db, inbox) async {
        final lists = ListsRepository(
          db,
          testClock('l'),
          // A prefix distinct from the inbox's own generator (also 'l',
          // seeded by pumpApp) so the two never collide on the same id.
          sequentialIds('gl'),
        );
        final groceries = await lists.create(name: 'Groceries');
        groceriesId = groceries.id;
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
        await repo.create(listId: groceriesId, title: 'Someday task');
      },
    );
    expect(find.text('No date'), findsOneWidget);
    expect(find.text('Someday task'), findsOneWidget);
    // Its row shows the list it belongs to.
    expect(find.text('Groceries'), findsOneWidget);
    // The "No date" header sits after the dated section, and the undated
    // task's title sits under that header.
    final datedY = tester.getTopLeft(find.text('Tomorrow task')).dy;
    final headerY = tester.getTopLeft(find.text('No date')).dy;
    final undatedY = tester.getTopLeft(find.text('Someday task')).dy;
    expect(datedY, lessThan(headerY));
    expect(headerY, lessThan(undatedY));
  });

  appTest('only an undated task: no empty state, the section shows', (
    tester,
  ) async {
    await pumpApp(
      tester,
      initialLocation: Routes.upcoming,
      seed: (db, inbox) async {
        await TasksRepository(
          db,
          testClock('s'),
          sequentialIds('t'),
          reminders: const NoopReminderScheduler(),
          now: () => testNow,
        ).create(listId: inbox.id, title: 'Someday task');
      },
    );
    expect(find.textContaining('Nothing planned'), findsNothing);
    expect(find.text('No date'), findsOneWidget);
    expect(find.text('Someday task'), findsOneWidget);
  });

  appTest('nothing at all: the combined empty text shows', (tester) async {
    await pumpApp(tester, initialLocation: Routes.upcoming);
    expect(
      find.text('Nothing planned. Tasks with a date or without one show here.'),
      findsOneWidget,
    );
  });

  appTest('tapping the No date header collapses it, and the choice persists', (
    tester,
  ) async {
    final app = await pumpApp(
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
        await repo.create(listId: inbox.id, title: 'Someday task');
      },
    );
    expect(find.text('Someday task'), findsOneWidget);

    await tester.tap(find.text('No date'));
    await tester.pumpAndSettle();
    expect(find.text('Someday task'), findsNothing);
    expect(
      await app.container.read(kvStoreProvider).get('upcoming.noDateCollapsed'),
      '1',
    );

    // Leaving and coming back keeps the section collapsed.
    app.router.go(Routes.today);
    await tester.pumpAndSettle();
    app.router.go(Routes.upcoming);
    await tester.pumpAndSettle();
    expect(find.text('Someday task'), findsNothing);
    expect(find.text('No date'), findsOneWidget);

    await tester.tap(find.text('No date'));
    await tester.pumpAndSettle();
    expect(find.text('Someday task'), findsOneWidget);
    expect(
      await app.container.read(kvStoreProvider).get('upcoming.noDateCollapsed'),
      '0',
    );
  });

  appTest('ticking the undated task off removes it from the section', (
    tester,
  ) async {
    await pumpApp(
      tester,
      initialLocation: Routes.upcoming,
      celebrate: true,
      seed: (db, inbox) async {
        final repo = TasksRepository(
          db,
          testClock('s'),
          sequentialIds('t'),
          reminders: const NoopReminderScheduler(),
          now: () => testNow,
        );
        await repo.create(listId: inbox.id, title: 'Warmup task');
        await repo.create(listId: inbox.id, title: 'Someday task');
      },
    );
    expect(find.text('Someday task'), findsOneWidget);
    // Spend the first-ever-completion achievement (a banner, no pill) on
    // this one, so the tick below is ordinary.
    await tickOff(tester, 'Warmup task');

    await tickOff(tester, 'Someday task');
    expect(find.text('Someday task'), findsNothing);
    expect(find.byKey(const Key('motivation-pill')), findsOneWidget);
  });
}
