import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/features/lists/data/lists_repository.dart';
import 'package:nemo/features/tasks/data/tasks_repository.dart';
import 'package:nemo_core/nemo_core.dart';

import '../support/test_db.dart';

/// Records what the app asked the platform to schedule or cancel.
class _RecordingScheduler implements ReminderScheduler {
  final synced = <Task>[];

  @override
  Future<void> init() async {}

  @override
  Future<bool> ensurePermission() async => true;

  @override
  Future<void> sync(Task task) async => synced.add(task);

  @override
  Future<void> cancel(String taskId) async {}
}

void main() {
  late AppDatabase db;
  late ListsRepository repo;
  late _RecordingScheduler reminders;

  setUp(() {
    db = testDatabase();
    reminders = _RecordingScheduler();
    repo = ListsRepository(
      db,
      testClock(),
      sequentialIds('l'),
      reminders: reminders,
    );
  });
  tearDown(() => db.close());

  test('ensureInbox creates one inbox and keeps it first', () async {
    final inbox = await repo.ensureInbox();
    expect(inbox.isInbox, isTrue);
    expect((await repo.ensureInbox()).id, inbox.id);
    await repo.create(name: ' Groceries ', color: 3);
    await repo.create(name: 'Work');
    final all = await repo.watchAll().first;
    expect(all.map((l) => l.name), ['Inbox', 'Groceries', 'Work']);
    expect(all[1].color, 3);
    expect(all[1].sortKey.compareTo(all[2].sortKey), lessThan(0));
  });

  test('devices that each made an Inbox end up with one', () async {
    // What sync does: every device makes its own Inbox before it has ever
    // spoken to a server, so an account used from four of them ends up
    // with four rows in the same table, each flagged as the Inbox. Four
    // and not two because that is what it took in the wild.
    final mine = await repo.ensureInbox();
    for (final id in ['a-from-phone', 'd-from-web', 'e-from-tablet']) {
      await db.upsertList(
        TaskList(
          id: id,
          name: 'Inbox',
          sortKey: SortKey.first(),
          isInbox: true,
          icon: 'inbox',
          updatedAt: testClock(id).now().toString(),
        ),
      );
    }
    final tasks = TasksRepository(
      db,
      testClock('t'),
      sequentialIds('t'),
      reminders: reminders,
      now: () => testNow,
    );
    final task = await tasks.create(listId: mine.id, title: 'Buy milk');
    // One that was written into a different device's Inbox, so the merge
    // has to gather from more than the one it happens to start on.
    final other = await tasks.create(
      listId: 'e-from-tablet',
      title: 'Fahrradschaltung einschalten',
    );

    // Used to throw `Bad state: Too many elements` out of the startup
    // path, which left the app showing nothing but a database error.
    final kept = await repo.ensureInbox();

    // The lowest id survives, so every device settles on the same one
    // without asking the server which.
    expect(kept.id, 'a-from-phone');
    expect(kept.isInbox, isTrue);
    final inboxes = (await repo.watchAll().first).where((l) => l.isInbox);
    expect(inboxes.map((l) => l.id), ['a-from-phone']);

    // Nothing is lost on the way, from any of them.
    for (final id in [task.id, other.id]) {
      final moved = await db.taskById(id);
      expect(moved!.listId, kept.id, reason: 'task $id moved to the survivor');
      expect(moved.deletedAt, isNull);
    }

    // And it is settled: asking again changes nothing.
    expect((await repo.ensureInbox()).id, kept.id);
  });

  test(
    'delete tombstones (never the inbox) and restore brings it back',
    () async {
      final inbox = await repo.ensureInbox();
      final work = await repo.create(name: 'Work');
      await repo.delete(inbox.id);
      await repo.delete(work.id);
      expect((await repo.watchAll().first).map((l) => l.id), [inbox.id]);
      expect((await db.listById(work.id))!.isDeleted, isTrue);
      await repo.restore(work.id);
      expect((await repo.watch(work.id).first)?.name, 'Work');
      expect(await db.outboxCount(), 2);
    },
  );

  test(
    'deleting a list takes its tasks, subtasks and reminders down',
    () async {
      final clock = testClock('device');
      final work = await repo.create(name: 'Work');
      final task = Task(
        id: 't1',
        listId: work.id,
        title: 'Ring the plumber',
        sortKey: 'V',
        remind: true,
        dueAt: testNow.add(const Duration(days: 1)).millisecondsSinceEpoch,
        updatedAt: clock.now().toString(),
      );
      await db.upsertTask(task);
      await db.upsertSubtask(
        Subtask(
          id: 's1',
          taskId: task.id,
          title: 'Find the number',
          sortKey: 'V',
          updatedAt: clock.now().toString(),
        ),
      );
      // A task deleted before the list, which the restore must leave alone.
      final earlier = task.copyWith(
        id: 't2',
        title: 'Already gone',
        updatedAt: clock.now().toString(),
        deletedAt: clock.now().toString(),
      );
      await db.upsertTask(earlier);

      await repo.delete(work.id);

      expect((await db.taskById('t1'))!.isDeleted, isTrue);
      expect((await db.subtaskById('s1'))!.isDeleted, isTrue);
      expect(
        reminders.synced.single.id,
        't1',
        reason: 'a hidden task went on posting notifications',
      );
      expect(
        wantsReminder(reminders.synced.single, testNow),
        isFalse,
        reason: 'the scheduler is told to drop it',
      );

      await repo.restore(work.id);

      expect((await db.taskById('t1'))!.isDeleted, isFalse);
      expect((await db.subtaskById('s1'))!.isDeleted, isFalse);
      expect(
        (await db.taskById('t2'))!.isDeleted,
        isTrue,
        reason: 'restoring a list revives what it took, not what came before',
      );
    },
  );

  test('save stamps a newer HLC', () async {
    final work = await repo.create(name: 'Work');
    await repo.save(work.copyWith(name: 'Job'));
    final saved = await db.listById(work.id);
    expect(saved!.name, 'Job');
    expect(saved.updatedAt.compareTo(work.updatedAt), greaterThan(0));
  });
}
