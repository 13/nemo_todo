import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/features/tasks/data/tasks_repository.dart';
import 'package:nemo/router.dart';

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
    expect(find.text('No tasks match "zzz".'), findsOneWidget);
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
}
