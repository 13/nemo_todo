import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/core/theme/app_style.dart';
import 'package:nemo/features/lists/data/lists_repository.dart';
import 'package:nemo/features/recently_deleted/ui/recently_deleted_screen.dart';
import 'package:nemo/features/tasks/data/tasks_repository.dart';
import 'package:nemo/router.dart';

import '../../support/pump_app.dart';
import '../../support/test_db.dart';

/// A list "Work" (`list1`) whose task "Call the plumber" (`task1`) was
/// deleted, and a list "Old" (`list2`), deleted with "Pay the bill"
/// (`task2`) in it.
Future<TestApp> _pump(
  WidgetTester tester,
  AppStyle style, {
  String location = Routes.lists,
  Size size = const Size(400, 800),
  bool empty = false,
}) => pumpApp(
  tester,
  initialLocation: location,
  size: size,
  seed: (db, inbox) async {
    await KvStore(db).set(KvKeys.appStyle, style.name);
    if (empty) return;
    final lists = ListsRepository(db, testClock('a'), sequentialIds('list'));
    final work = await lists.create(name: 'Work');
    final old = await lists.create(name: 'Old');
    final tasks = TasksRepository(
      db,
      testClock('a'),
      sequentialIds('task'),
      reminders: const NoopReminderScheduler(),
      now: () => testNow,
    );
    final call = await tasks.create(listId: work.id, title: 'Call the plumber');
    await tasks.create(listId: old.id, title: 'Pay the bill');
    await tasks.delete(call.id);
    await lists.delete(old.id);
  },
);

/// Goes to Recently deleted the way [style] offers it.
Future<void> _open(WidgetTester tester, AppStyle style) async {
  if (style == AppStyle.macos) {
    await tester.tap(find.byKey(const Key('recently-deleted')));
  } else {
    await tester.tap(find.byTooltip('Settings').first);
    await tester.pumpAndSettle();
    await scrollIntoView(tester, find.byKey(const Key('recently-deleted')));
    await tester.tap(find.byKey(const Key('recently-deleted')));
  }
  await tester.pumpAndSettle();
  expect(find.byType(RecentlyDeletedScreen), findsOneWidget);
}

void main() {
  for (final style in AppStyle.values) {
    group(style.name, () {
      appTest('lists deleted tasks and brings one back into its list', (
        tester,
      ) async {
        final app = await _pump(tester, style);
        await _open(tester, style);

        expect(find.text('Call the plumber'), findsOneWidget);
        expect(find.textContaining('Goes back to Work'), findsOneWidget);
        expect(find.byKey(const Key('deleted-list-list2')), findsOneWidget);
        expect(find.text('Old'), findsOneWidget);
        expect(find.textContaining('1 task'), findsOneWidget);
        expect(
          find.text('Pay the bill'),
          findsNothing,
          reason: 'it went down with its list, and comes back with it',
        );

        await tester.tap(find.byKey(const Key('restore-task1')));
        await tester.pumpAndSettle();

        expect(find.text('Task restored to Work'), findsOneWidget);
        expect(find.text('Call the plumber'), findsNothing);
        final back = (await app.db.taskById('task1'))!;
        expect(back.deletedAt, isNull);
        expect(back.listId, 'list1');
      });

      appTest('brings a list back with its tasks', (tester) async {
        final app = await _pump(tester, style);
        await _open(tester, style);

        await tester.tap(find.byKey(const Key('restore-list-list2')));
        await tester.pumpAndSettle();

        expect(find.text('List restored'), findsOneWidget);
        expect(find.byKey(const Key('deleted-list-list2')), findsNothing);
        expect((await app.db.listById('list2'))!.deletedAt, isNull);
        final task = (await app.db.taskById('task2'))!;
        expect(task.deletedAt, isNull);
        expect(task.listId, 'list2');
      });

      appTest('deletes a task and a list for good after asking', (
        tester,
      ) async {
        final app = await _pump(tester, style);
        await _open(tester, style);

        await tester.tap(find.byKey(const Key('erase-task1')));
        await tester.pumpAndSettle();
        expect(find.textContaining('cannot be brought back'), findsOneWidget);
        await tester.tap(find.byKey(const Key('confirm-erase')));
        await tester.pumpAndSettle();
        expect(find.text('Call the plumber'), findsNothing);
        final gone = (await app.db.taskById('task1'))!;
        expect(gone.isDeleted, isTrue);
        expect(gone.title, isEmpty);

        await tester.tap(find.byKey(const Key('erase-list-list2')));
        await tester.pumpAndSettle();
        expect(find.textContaining('everything in it'), findsOneWidget);
        await tester.tap(find.byKey(const Key('confirm-erase')));
        await tester.pumpAndSettle();
        expect((await app.db.listById('list2'))!.name, isEmpty);
        expect((await app.db.taskById('task2'))!.title, isEmpty);
        expect(
          find.text('Nothing deleted in the last 30 days'),
          findsOneWidget,
        );
      });

      appTest('says when nothing was deleted', (tester) async {
        await _pump(
          tester,
          style,
          location: Routes.recentlyDeleted,
          empty: true,
        );
        expect(
          find.text('Nothing deleted in the last 30 days'),
          findsOneWidget,
        );
      });
    });
  }

  appTest('a Mac window has it at the end of the sidebar', (tester) async {
    await _pump(tester, AppStyle.macos, size: const Size(1200, 800));
    await tester.tap(find.byKey(const Key('sidebar-recently-deleted')));
    await tester.pumpAndSettle();
    expect(find.byType(RecentlyDeletedScreen), findsOneWidget);
    expect(find.text('Call the plumber'), findsOneWidget);
  });
}
