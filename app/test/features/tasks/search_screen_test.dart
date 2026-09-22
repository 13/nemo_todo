import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/core/widgets/async_body.dart';
import 'package:nemo/features/tasks/data/tasks_repository.dart';
import 'package:nemo/router.dart';
import 'package:nemo_core/nemo_core.dart';

import '../../support/pump_app.dart';
import '../../support/test_db.dart';

void main() {
  appTest('filters tasks as you type', (tester) async {
    await pumpApp(
      tester,
      initialLocation: Routes.search,
      seed: (db, inbox) async {
        final repo = TasksRepository(
          db,
          testClock('s'),
          sequentialIds('t'),
          reminders: const NoopReminderScheduler(),
          now: () => testNow,
        );
        await repo.create(listId: inbox.id, title: 'Buy milk', tags: ['home']);
        await repo.create(listId: inbox.id, title: 'Call mum');
      },
    );
    expect(find.text('Type to search across all lists.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('search-field')), 'milk');
    await tester.pumpAndSettle();
    expect(find.text('Buy milk'), findsOneWidget);
    expect(find.text('Call mum'), findsNothing);
    await tester.enterText(find.byKey(const Key('search-field')), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Nothing matches "zzz".'), findsOneWidget);
  });

  appTest('search finds a note by its body', (tester) async {
    final harness = await pumpApp(tester, initialLocation: Routes.search);
    await harness.seedList('l1', 'Kitchen');
    await harness.seedNote('n1', 'l1', title: 'Bread', body: '500 g flour');
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('search-field')), 'flour');
    await tester.pumpAndSettle();

    // Scoped to the results header, not the bottom navigation bar's own
    // "Notes" destination label, which `find.text('Notes')` alone would
    // also match at this window size.
    expect(
      find.descendant(
        of: find.byKey(const Key('search-notes-header')),
        matching: find.text('Notes'),
      ),
      findsOneWidget,
    );
    expect(find.text('Bread'), findsOneWidget);
  });

  appTest('shows tasks and notes as one scrolling flow', (tester) async {
    final harness = await pumpApp(
      tester,
      initialLocation: Routes.search,
      seed: (db, inbox) async {
        final repo = TasksRepository(
          db,
          testClock('s'),
          sequentialIds('t'),
          reminders: const NoopReminderScheduler(),
          now: () => testNow,
        );
        await repo.create(listId: inbox.id, title: 'Buy bread');
      },
    );
    await harness.seedNote(
      'n1',
      harness.inbox.id,
      title: 'Bread starter',
      body: 'feed daily',
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('search-field')), 'bread');
    await tester.pumpAndSettle();

    // Both sections, each under its own header, in one place.
    expect(find.text('Tasks'), findsOneWidget);
    expect(find.text('Buy bread'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('search-notes-header')),
        matching: find.text('Notes'),
      ),
      findsOneWidget,
    );
    expect(find.text('Bread starter'), findsOneWidget);

    // One continuous scroll over the results, not a second independently
    // scrolling pane: exactly one Scrollable inside the results area (the
    // search field's own text-editing Scrollable lives outside it, in the
    // app bar).
    expect(
      find.descendant(
        of: find.byType(AsyncBody<List<Task>>),
        matching: find.byType(Scrollable),
      ),
      findsOneWidget,
    );
  });
}
