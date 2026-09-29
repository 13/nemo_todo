import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/notifications/reminder_resync.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/features/daily_list/daily_list_providers.dart';
import 'package:nemo/features/lists/data/lists_repository.dart';
import 'package:nemo/features/reminders/reminders_providers.dart';
import 'package:nemo/features/tasks/ui/tasks_providers.dart';
import 'package:nemo_core/nemo_core.dart';

import '../../support/test_db.dart';

/// Records which tasks were synced and cancelled, in order.
class RecordingScheduler implements ReminderScheduler {
  final synced = <String>[];
  final cancelled = <String>[];

  @override
  Future<bool> ensurePermission() async => true;

  @override
  Future<void> sync(Task task) async => synced.add(task.id);

  @override
  Future<void> cancel(String taskId) async => cancelled.add(taskId);
}

Task _task(String id) => Task(
  id: id,
  listId: 'l',
  title: id,
  sortKey: 'V',
  updatedAt: '0000000000001-0000-n',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReminderResync', () {
    test('syncs every task and cancels the ones that left', () async {
      final scheduler = RecordingScheduler();
      final resync = ReminderResync(scheduler);
      await resync.apply([_task('a'), _task('b')]);
      expect(scheduler.synced, ['a', 'b']);
      expect(scheduler.cancelled, isEmpty);
      await resync.apply([_task('b'), _task('c')]);
      expect(scheduler.synced, ['a', 'b', 'b', 'c']);
      expect(scheduler.cancelled, ['a']);
      await resync.apply([]);
      expect(scheduler.cancelled, ['a', 'b', 'c']);
    });
  });

  group('reminderResyncProvider', () {
    late RecordingScheduler scheduler;
    late String inbox;
    late ProviderContainer container;

    Future<void> settle() =>
        Future<void>.delayed(const Duration(milliseconds: 150));

    Future<void> start({required bool inPage}) async {
      final db = testDatabase();
      addTearDown(db.close);
      inbox = (await ListsRepository(
        db,
        testClock(),
        sequentialIds('l'),
      ).ensureInbox()).id;
      final boot = await AppBootstrap.load(db);
      scheduler = RecordingScheduler();
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          bootstrapProvider.overrideWithValue(boot),
          nowProvider.overrideWithValue(() => testNow),
          idGeneratorProvider.overrideWithValue(sequentialIds()),
          reminderSchedulerProvider.overrideWithValue(scheduler),
          remindersInPageProvider.overrideWithValue(inPage),
          dailyListDebounceProvider.overrideWithValue(
            const Duration(milliseconds: 50),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(reminderResyncProvider);
      await settle();
    }

    test('in the page: a task written anywhere is resynced', () async {
      await start(inPage: true);
      final tasks = container.read(tasksRepositoryProvider);
      final task = await tasks.create(
        listId: inbox,
        title: 'Dentist',
        dueAt: testNow.millisecondsSinceEpoch,
      );
      await settle();
      expect(scheduler.synced, contains(task.id));
      scheduler.cancelled.clear();
      await tasks.setDone(task.id, done: true);
      await settle();
      // Gone from the open tasks, as a tick in another tab would be.
      expect(scheduler.cancelled, contains(task.id));
    });

    test('where reminders outlive the app, it does nothing', () async {
      await start(inPage: false);
      await container
          .read(tasksRepositoryProvider)
          .create(
            listId: inbox,
            title: 'Dentist',
            dueAt: testNow.millisecondsSinceEpoch,
          );
      await settle();
      // Only the repository's own sync, never a resync pass.
      expect(scheduler.synced, hasLength(1));
    });
  });
}
