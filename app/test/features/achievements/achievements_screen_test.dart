import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/features/achievements/domain/completion_stats.dart';
import 'package:nemo/features/achievements/ui/achievements_providers.dart';
import 'package:nemo/features/tasks/data/tasks_repository.dart';
import 'package:nemo/router.dart';

import '../../support/pump_app.dart';
import '../../support/test_db.dart';

void main() {
  appTest('shows unlocked and locked achievements', (tester) async {
    await pumpApp(
      tester,
      initialLocation: Routes.achievements,
      seed: (db, inbox) async {
        final tasks = TasksRepository(
          db,
          testClock('seed'),
          sequentialIds('task'),
          reminders: const NoopReminderScheduler(),
          now: () => testNow,
        );
        final t = await tasks.create(listId: inbox.id, title: 'Done');
        await tasks.setDone(t.id, done: true);
      },
    );

    expect(find.text('Achievements'), findsOneWidget);
    expect(find.text('1 of 10 unlocked'), findsOneWidget);
    expect(find.text('1-day streak'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('achievement-first_done')),
        matching: find.text('Unlocked'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('achievement-done_10')),
        matching: find.text('1 / 10'),
      ),
      findsOneWidget,
    );
  });

  appTest('a failed stats query says so instead of spinning', (tester) async {
    await pumpApp(
      tester,
      initialLocation: Routes.achievements,
      overrides: [
        completionStatsProvider.overrideWith(
          (ref) => Stream<CompletionStats>.error(StateError('broken')),
        ),
      ],
    );

    expect(find.text('Achievements could not be loaded.'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
