import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/features/lists/data/lists_repository.dart';
import 'package:nemo/features/tasks/data/subtasks_repository.dart';
import 'package:nemo/features/tasks/data/tasks_repository.dart';
import 'package:nemo/utils/dates.dart';
import 'package:nemo_core/nemo_core.dart';

import '../support/test_db.dart';

class RecordingScheduler implements ReminderScheduler {
  final synced = <Task>[];
  final cancelled = <String>[];

  @override
  Future<void> init() async {}

  @override
  Future<bool> ensurePermission() async => true;

  @override
  Future<void> sync(Task task) async => synced.add(task);

  @override
  Future<void> cancel(String taskId) async => cancelled.add(taskId);
}

void main() {
  late AppDatabase db;
  late TasksRepository tasks;
  late SubtasksRepository subtasks;
  late RecordingScheduler scheduler;
  late String inbox;

  setUp(() async {
    db = testDatabase();
    scheduler = RecordingScheduler();
    final clock = testClock();
    final ids = sequentialIds();
    inbox = (await ListsRepository(db, clock, ids).ensureInbox()).id;
    tasks = TasksRepository(
      db,
      clock,
      ids,
      reminders: scheduler,
      now: () => testNow,
    );
    subtasks = SubtasksRepository(db, clock, ids);
  });
  tearDown(() => db.close());

  test('create appends in order and setDone records doneAt', () async {
    final a = await tasks.create(listId: inbox, title: 'A');
    final b = await tasks.create(listId: inbox, title: 'B');
    expect(a.sortKey.compareTo(b.sortKey), lessThan(0));
    await tasks.setDone(a.id, done: true);
    final list = await tasks.watchByList(inbox).first;
    expect(list.map((t) => t.title), ['B', 'A'], reason: 'done tasks sink');
    expect(list.last.doneAt, testNow.millisecondsSinceEpoch);
    await tasks.setDone(a.id, done: false);
    expect((await db.taskById(a.id))!.doneAt, isNull);
    expect(scheduler.synced.map((t) => t.id), ['id2', 'id3', 'id2', 'id2']);
  });

  test(
    'today shows overdue, due today and done today; upcoming the rest',
    () async {
      final yesterday = dayStartMsFrom(testNow, -1);
      final today = composeDue(testNow, hour: 15);
      final tomorrow = dayStartMsFrom(testNow, 1);
      await tasks.create(listId: inbox, title: 'late', dueAt: yesterday);
      await tasks.create(
        listId: inbox,
        title: 'now',
        dueAt: today,
        dueHasTime: true,
      );
      await tasks.create(listId: inbox, title: 'soon', dueAt: tomorrow);
      await tasks.create(listId: inbox, title: 'never');
      final doneOld = await tasks.create(
        listId: inbox,
        title: 'done-old',
        dueAt: yesterday,
      );
      await tasks.save(doneOld.copyWith(done: true, doneAt: yesterday));
      final doneNow = await tasks.create(
        listId: inbox,
        title: 'done-now',
        dueAt: today,
      );
      await tasks.setDone(doneNow.id, done: true);

      expect((await tasks.watchToday(testNow).first).map((t) => t.title), [
        'late',
        'now',
        'done-now',
      ]);
      expect((await tasks.watchUpcoming(testNow).first).map((t) => t.title), [
        'soon',
      ]);
    },
  );

  test('tasks of a deleted list disappear from today and search', () async {
    final lists = ListsRepository(db, testClock('x'), sequentialIds('l'));
    final work = await lists.create(name: 'Work');
    await tasks.create(
      listId: work.id,
      title: 'report',
      dueAt: dayStartMs(testNow),
      tags: ['office'],
    );
    expect((await tasks.search('OFFICE').first).map((t) => t.title), [
      'report',
    ]);
    await lists.delete(work.id);
    expect(await tasks.watchToday(testNow).first, isEmpty);
    expect(await tasks.search('report').first, isEmpty);
  });

  test(
    'search matches title, notes and tags; empty query yields nothing',
    () async {
      await tasks.create(
        listId: inbox,
        title: 'Buy milk',
        notes: 'oat',
        tags: ['home'],
      );
      await tasks.create(listId: inbox, title: 'Call mum');
      expect((await tasks.search('milk').first).length, 1);
      expect((await tasks.search('oat').first).length, 1);
      expect((await tasks.search('home').first).length, 1);
      expect(await tasks.search('  ').first, isEmpty);
      expect(await tasks.allTags(), ['home']);
    },
  );

  test('delete tombstones and reorders only the moved row', () async {
    final a = await tasks.create(listId: inbox, title: 'A');
    final b = await tasks.create(listId: inbox, title: 'B');
    final c = await tasks.create(listId: inbox, title: 'C');
    await tasks.placeBetween(c.id, after: a.id);
    expect((await tasks.watchByList(inbox).first).map((t) => t.title), [
      'C',
      'A',
      'B',
    ]);
    await tasks.placeBetween(a.id, before: c.id, after: b.id);
    expect(
      (await db.taskById(b.id))!.sortKey,
      b.sortKey,
      reason: 'neighbours untouched',
    );
    await tasks.delete(b.id);
    expect((await tasks.watchByList(inbox).first).map((t) => t.title), [
      'C',
      'A',
    ]);
    expect((await db.taskById(b.id))!.isDeleted, isTrue);
    await tasks.restore(b.id);
    expect((await tasks.watch(b.id).first)?.title, 'B');
    expect(await tasks.watchOpenCount(inbox).first, 3);
  });

  test('subtasks: add, progress, reorder, delete', () async {
    final t = await tasks.create(listId: inbox, title: 'T');
    final s1 = await subtasks.add(t.id, 'one');
    final s2 = await subtasks.add(t.id, 'two');
    await subtasks.save(s1.copyWith(done: true));
    expect((await subtasks.watchProgress().first)[t.id], (done: 1, total: 2));
    await subtasks.placeBetween(s2.id, after: s1.id);
    expect((await subtasks.watchByTask(t.id).first).map((s) => s.title), [
      'two',
      'one',
    ]);
    await subtasks.delete(s2.id);
    expect((await subtasks.watchByTask(t.id).first).map((s) => s.title), [
      'one',
    ]);
  });

  test('completing a repeating task puts the next one on the list', () async {
    final due = composeDue(testNow, hour: 9);
    final weekly = await tasks.create(
      listId: inbox,
      title: 'Water the plants',
      dueAt: due,
      dueHasTime: true,
      remind: true,
      repeat: Repeats.weekly,
    );
    await subtasks.add(weekly.id, 'Kitchen');
    await subtasks.add(weekly.id, 'Balcony');
    final first = (await subtasks.watchByTask(weekly.id).first).first;
    await subtasks.save(first.copyWith(done: true));

    await tasks.setDone(weekly.id, done: true);

    final open = (await tasks.watchByList(inbox).first)
        .where((t) => !t.done)
        .toList();
    expect(open, hasLength(1));
    final next = open.single;
    expect(
      next.id,
      isNot(weekly.id),
      reason: 'an ordinary new row, not an edit',
    );
    expect(next.title, 'Water the plants');
    expect(next.repeat, 'weekly');
    expect(next.remind, isTrue);
    expect(
      DateTime.fromMillisecondsSinceEpoch(next.dueAt!),
      DateTime.fromMillisecondsSinceEpoch(due).add(const Duration(days: 7)),
    );
    expect((await db.taskById(weekly.id))!.done, isTrue);

    final carried = await subtasks.watchByTask(next.id).first;
    expect(carried.map((s) => s.title), ['Kitchen', 'Balcony']);
    expect(
      carried.every((s) => !s.done),
      isTrue,
      reason: 'a checklist that arrives already ticked is not a checklist',
    );
  });

  test('a weekdays rule skips the weekend on the way back', () async {
    // Friday. Completing it should put Monday on the list, not Saturday.
    final friday = DateTime(2026, 9, 11, 8);
    final task = await tasks.create(
      listId: inbox,
      title: 'Water the office plant',
      dueAt: friday.millisecondsSinceEpoch,
      repeat: Repeats.weekdays,
    );
    await tasks.setDone(task.id, done: true);

    final next = (await tasks.watchByList(inbox).first).firstWhere(
      (t) => !t.done,
    );
    final due = DateTime.fromMillisecondsSinceEpoch(next.dueAt!);
    expect(due.weekday, DateTime.monday);
    expect(due, DateTime(2026, 9, 14, 8));
    expect(next.repeat, 'weekdays');
  });

  test('a repeating task with no due date just completes', () async {
    final task = await tasks.create(
      listId: inbox,
      title: 'Someday',
      repeat: Repeats.daily,
    );
    expect(task.repeat, isNull, reason: 'nothing to count a rule from');
    await tasks.setDone(task.id, done: true);
    expect(await tasks.watchByList(inbox).first, hasLength(1));
  });

  test('unticking a repeating task does not spawn another', () async {
    final task = await tasks.create(
      listId: inbox,
      title: 'Bins',
      dueAt: composeDue(testNow, hour: 8),
      repeat: Repeats.weekly,
    );
    await tasks.setDone(task.id, done: true);
    expect(await tasks.watchByList(inbox).first, hasLength(2));
    await tasks.setDone(task.id, done: false);
    expect(await tasks.watchByList(inbox).first, hasLength(2));
  });

  test('wantsReminder only for open future tasks with remind on', () {
    final due = testNow.add(const Duration(hours: 1)).millisecondsSinceEpoch;
    Task t({
      bool remind = true,
      bool done = false,
      int? dueAt,
      String? deletedAt,
    }) => Task(
      id: 'x',
      listId: 'l',
      title: 'x',
      sortKey: 'V',
      updatedAt: '0000000000001-0000-n',
      remind: remind,
      done: done,
      dueAt: dueAt ?? due,
      deletedAt: deletedAt,
    );
    expect(wantsReminder(t(), testNow), isTrue);
    expect(wantsReminder(t(remind: false), testNow), isFalse);
    expect(wantsReminder(t(done: true), testNow), isFalse);
    expect(wantsReminder(t(deletedAt: 'x'), testNow), isFalse);
    expect(
      wantsReminder(t(dueAt: testNow.millisecondsSinceEpoch - 1), testNow),
      isFalse,
    );
  });
}
