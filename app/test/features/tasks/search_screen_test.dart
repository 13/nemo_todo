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
}
