import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/features/sync/ui/sync_engine.dart';
import 'package:nemo/features/sync/ui/sync_state.dart';
import 'package:nemo/features/tasks/data/tasks_repository.dart';
import 'package:nemo/router.dart';
import 'package:nemo/utils/dates.dart';

import '../../support/pump_app.dart';
import '../../support/test_db.dart';

/// Connected and idle, recording every [syncNow] call without doing
/// anything else: enough to prove a pull reached the engine, without the
/// spinner-timing behaviour `sync_refresh_test.dart` already covers.
class _SignedInEngine extends SyncEngine {
  // A test fake: the count is read by the test, not by any provider.
  // ignore: riverpod_lint/avoid_public_notifier_properties
  int calls = 0;

  @override
  SyncState build() => const SyncState(status: SyncStatus.idle);

  @override
  Future<void> syncNow() async => calls++;
}

TasksRepository _tasks(AppDatabase db) => TasksRepository(
  db,
  testClock('s'),
  sequentialIds('t'),
  reminders: const NoopReminderScheduler(),
  now: () => testNow,
);

Future<void> _pull(WidgetTester tester, Finder finder) async {
  await tester.fling(finder, const Offset(0, 400), 1000);
  await tester.pumpAndSettle();
}

void main() {
  appTest('Today: a pull syncs', (tester) async {
    final engine = _SignedInEngine();
    await pumpApp(
      tester,
      overrides: [syncEngineProvider.overrideWith(() => engine)],
      seed: (db, inbox) async {
        await _tasks(db)
            .create(listId: inbox.id, title: 'Row', dueAt: dayStartMs(testNow));
      },
    );
    expect(find.byKey(const Key('sync-refresh')), findsOneWidget);
    await _pull(tester, find.text('Row'));
    expect(engine.calls, 1);
  });

  appTest('Today empty state: a pull syncs', (tester) async {
    final engine = _SignedInEngine();
    await pumpApp(
      tester,
      overrides: [syncEngineProvider.overrideWith(() => engine)],
    );
    expect(find.byKey(const Key('sync-refresh')), findsOneWidget);
    await _pull(tester, find.text('Nothing due today. Enjoy the calm.'));
    expect(engine.calls, 1);
  });

  appTest('Upcoming: a pull syncs', (tester) async {
    final engine = _SignedInEngine();
    await pumpApp(
      tester,
      initialLocation: Routes.upcoming,
      overrides: [syncEngineProvider.overrideWith(() => engine)],
      seed: (db, inbox) async {
        await _tasks(db).create(
          listId: inbox.id,
          title: 'Row',
          dueAt: dayStartMsFrom(testNow, 1),
        );
      },
    );
    expect(find.byKey(const Key('sync-refresh')), findsOneWidget);
    await _pull(tester, find.text('Row'));
    expect(engine.calls, 1);
  });

  appTest('Lists: a pull syncs', (tester) async {
    final engine = _SignedInEngine();
    await pumpApp(
      tester,
      initialLocation: Routes.lists,
      overrides: [syncEngineProvider.overrideWith(() => engine)],
    );
    expect(find.byKey(const Key('sync-refresh')), findsOneWidget);
    await _pull(tester, find.text('Inbox'));
    expect(engine.calls, 1);
  });

  appTest('List detail: a pull syncs', (tester) async {
    final engine = _SignedInEngine();
    final harness = await pumpApp(
      tester,
      overrides: [syncEngineProvider.overrideWith(() => engine)],
    );
    await harness.seedList('l1', 'Groceries');
    await harness.seedTask('t1', 'l1', title: 'Row');
    harness.router.go(Routes.list('l1'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sync-refresh')), findsOneWidget);
    await _pull(tester, find.text('Row'));
    expect(engine.calls, 1);
  });

  appTest('Notes: a pull syncs', (tester) async {
    final engine = _SignedInEngine();
    final harness = await pumpApp(
      tester,
      initialLocation: Routes.notes,
      overrides: [syncEngineProvider.overrideWith(() => engine)],
    );
    await harness.seedList('l1', 'Kitchen');
    await harness.seedNote('n1', 'l1', title: 'Row');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sync-refresh')), findsOneWidget);
    await _pull(tester, find.text('Row'));
    expect(engine.calls, 1);
  });

  appTest('Notes empty state: a pull syncs', (tester) async {
    final engine = _SignedInEngine();
    await pumpApp(
      tester,
      initialLocation: Routes.notes,
      overrides: [syncEngineProvider.overrideWith(() => engine)],
    );
    expect(find.byKey(const Key('sync-refresh')), findsOneWidget);
    await _pull(tester, find.textContaining('No notes yet'));
    expect(engine.calls, 1);
  });

  appTest('Tag: a pull syncs', (tester) async {
    final engine = _SignedInEngine();
    await pumpApp(
      tester,
      initialLocation: Routes.tag('x'),
      overrides: [syncEngineProvider.overrideWith(() => engine)],
      seed: (db, inbox) async {
        await _tasks(db).create(listId: inbox.id, title: 'Row', tags: ['x']);
      },
    );
    expect(find.byKey(const Key('sync-refresh')), findsOneWidget);
    await _pull(tester, find.text('Row'));
    expect(engine.calls, 1);
  });

  appTest('Search results: a pull syncs', (tester) async {
    final engine = _SignedInEngine();
    await pumpApp(
      tester,
      initialLocation: Routes.search,
      overrides: [syncEngineProvider.overrideWith(() => engine)],
      seed: (db, inbox) async {
        await _tasks(db).create(listId: inbox.id, title: 'Row');
      },
    );
    await tester.enterText(find.byKey(const Key('search-field')), 'Row');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sync-refresh')), findsOneWidget);
    // 'Row' also matches the search field's own EditableText; scope to the
    // results list to pull on the task tile instead.
    await _pull(
      tester,
      find.descendant(
        of: find.byKey(const Key('sync-refresh')),
        matching: find.text('Row'),
      ),
    );
    expect(engine.calls, 1);
  });

  appTest('no account: Today has no sync-refresh indicator', (tester) async {
    await pumpApp(tester);
    expect(find.byKey(const Key('sync-refresh')), findsNothing);
  });
}
