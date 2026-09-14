import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/features/lists/data/lists_repository.dart';
import 'package:nemo/features/settings/data/data_export.dart';
import 'package:nemo/features/tasks/data/subtasks_repository.dart';
import 'package:nemo/features/tasks/data/tasks_repository.dart';

import '../../support/test_db.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = testDatabase());
  tearDown(() => db.close());

  Future<void> seed(AppDatabase db) async {
    final lists = ListsRepository(db, testClock('a'), sequentialIds('l'));
    final tasks = TasksRepository(
      db,
      testClock('a'),
      sequentialIds('t'),
      reminders: const NoopReminderScheduler(),
      now: () => testNow,
    );
    final subtasks = SubtasksRepository(db, testClock('a'), sequentialIds('s'));
    final inbox = await lists.ensureInbox();
    final work = await lists.create(name: 'Work');
    final report = await tasks.create(listId: work.id, title: 'Report');
    await tasks.create(listId: inbox.id, title: 'Milk');
    await subtasks.add(report.id, 'Draft');
    final gone = await tasks.create(listId: work.id, title: 'Deleted one');
    await tasks.delete(gone.id);
  }

  test('exports what is alive, and a fresh device takes all of it', () async {
    await seed(db);
    final text = await DataExport(db, testClock('a')).export(now: testNow);
    final json = jsonDecode(text) as Map<String, dynamic>;
    expect(json['format'], 'nemo-export');
    expect(json['lists'], hasLength(2));
    expect(
      [for (final t in json['tasks'] as List) (t as Map)['title']],
      ['Report', 'Milk'],
    );
    expect(json['subtasks'], hasLength(1));

    final fresh = testDatabase();
    addTearDown(fresh.close);
    final added = await DataExport(fresh, testClock('b')).import(text);
    expect(added, 5);
    expect(await fresh.select(fresh.tasks).get(), hasLength(2));
    expect(await fresh.outboxCount(), 5, reason: 'queued for the server');
  });

  test('importing twice adds nothing the second time', () async {
    await seed(db);
    final export = DataExport(db, testClock('a'));
    final text = await export.export(now: testNow);
    expect(await export.import(text), 0);
  });

  test('a deleted task comes back, newer than its deletion', () async {
    await seed(db);
    // One clock for the deletion and the import, the way a device has one:
    // two frozen clocks would hand out the same stamp.
    final clock = testClock('a');
    final export = DataExport(db, clock);
    final text = await export.export(now: testNow);
    final milk = (await db.select(db.tasks).get()).firstWhere(
      (t) => t.title == 'Milk',
    );
    final stamp = clock.now().toString();
    final tombstone = milk.copyWith(deletedAt: stamp, updatedAt: stamp);
    await db.upsertTask(tombstone);

    expect(await export.import(text), 1);
    final back = (await db.taskById(milk.id))!;
    expect(back.isDeleted, isFalse);
    expect(back.updatedAt.compareTo(tombstone.updatedAt), greaterThan(0));
  });

  test('anything but an export is refused before a row is written', () async {
    final export = DataExport(db, testClock('a'));
    for (final text in [
      'not json',
      '[]',
      '{"format":"something-else","version":1}',
      '{"format":"nemo-export","version":99}',
      '{"format":"nemo-export","version":1,"tasks":[{"id":1}]}',
    ]) {
      await expectLater(export.import(text), throwsFormatException);
    }
    expect(await db.select(db.lists).get(), isEmpty);
  });
}
