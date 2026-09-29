import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/features/lists/data/lists_repository.dart';
import 'package:nemo/features/photos/data/photo_pipeline.dart';
import 'package:nemo/features/photos/data/photo_store_web.dart';
import 'package:nemo/features/photos/data/photos_repository.dart';
import 'package:nemo/features/recently_deleted/data/recently_deleted_repository.dart';
import 'package:nemo/features/tasks/data/subtasks_repository.dart';
import 'package:nemo/features/tasks/data/tasks_repository.dart';
import 'package:nemo_core/nemo_core.dart';

import '../../support/photos.dart';
import '../../support/test_db.dart';

void main() {
  late AppDatabase db;
  late HlcClock clock;
  late ListsRepository lists;
  late TasksRepository tasks;
  late SubtasksRepository subtasks;
  late MemoryPhotoStore store;
  late PhotosRepository photos;
  late RecentlyDeletedRepository bin;
  late TaskList inbox;
  late TaskList work;

  /// Tasks repository whose clock reads [ago] before now, to delete
  /// things in the past.
  TasksRepository deletingAgo(Duration ago) => TasksRepository(
    db,
    HlcClock(node: 'past', now: () => testNow.subtract(ago)),
    sequentialIds('old'),
    reminders: const NoopReminderScheduler(),
    now: () => testNow.subtract(ago),
  );

  setUp(() async {
    db = testDatabase();
    clock = testClock('dev');
    final ids = sequentialIds();
    lists = ListsRepository(db, clock, ids);
    inbox = await lists.ensureInbox();
    work = await lists.create(name: 'Work');
    tasks = TasksRepository(
      db,
      clock,
      ids,
      reminders: const NoopReminderScheduler(),
      now: () => testNow,
    );
    subtasks = SubtasksRepository(db, clock, ids);
    store = MemoryPhotoStore();
    photos = PhotosRepository(
      db,
      clock,
      ids,
      store,
      process: (raw) async => processPhoto(raw),
    );
    bin = RecentlyDeletedRepository(
      db,
      clock,
      lists: lists,
      tasks: tasks,
      store: store,
      now: () => testNow,
    );
  });
  tearDown(() => db.close());

  test('lists what was deleted within the window, newest first', () async {
    final old = await tasks.create(listId: work.id, title: 'Old');
    final recent = await tasks.create(listId: work.id, title: 'Recent');
    final newest = await tasks.create(listId: work.id, title: 'Newest');
    await tasks.create(listId: work.id, title: 'Alive');
    await deletingAgo(const Duration(days: 31)).delete(old.id);
    await deletingAgo(const Duration(days: 29)).delete(recent.id);
    await tasks.delete(newest.id);

    final shown = await bin.watch().first;

    expect(shown.map((d) => d.task.title), ['Newest', 'Recent']);
    expect(shown.first.list?.id, work.id);
  });

  test(
    'a task deleted with its list is there, with no list to go to',
    () async {
      final t = await tasks.create(listId: work.id, title: 'In work');
      await lists.delete(work.id);

      final shown = await bin.watch().first;

      expect(shown.single.task.id, t.id);
      expect(shown.single.list, isNull, reason: 'it goes back to the Inbox');
    },
  );

  test('restore brings the task back as a newer edit, queued', () async {
    final t = await tasks.create(listId: work.id, title: 'Back');
    await tasks.delete(t.id);
    final tombstone = (await db.taskById(t.id))!;
    await db.clearOutbox();

    final to = await bin.restore(t.id);

    final back = (await db.taskById(t.id))!;
    expect(to?.id, work.id);
    expect(back.deletedAt, isNull);
    expect(back.listId, work.id);
    expect(back.updatedAt.compareTo(tombstone.updatedAt), greaterThan(0));
    expect(incomingWins(tombstone, back), isTrue);
    expect(await db.outboxCount(), 1);
    expect(await bin.watch().first, isEmpty);
  });

  test(
    'restore puts a task whose list is gone at the end of the Inbox',
    () async {
      await tasks.create(listId: inbox.id, title: 'Already there');
      final t = await tasks.create(listId: work.id, title: 'Homeless');
      final sub = await subtasks.add(t.id, 'with it');
      final earlier = await subtasks.add(t.id, 'deleted before');
      await subtasks.delete(earlier.id);
      await lists.delete(work.id);

      final to = await bin.restore(t.id);

      expect(to?.id, inbox.id);
      final back = (await db.taskById(t.id))!;
      expect(back.listId, inbox.id);
      expect(back.deletedAt, isNull);
      final open = await tasks.watchByList(inbox.id).first;
      expect(open.last.id, t.id, reason: 'at the end, not among the others');
      expect((await db.subtaskById(sub.id))!.deletedAt, isNull);
      expect(
        (await db.subtaskById(earlier.id))!.deletedAt,
        isNotNull,
        reason: 'it was deleted on its own, before',
      );
      expect(
        await lists.watch(work.id).first,
        isNull,
        reason: 'the list stays deleted',
      );
    },
  );

  test('delete now erases the text and falls out of every window', () async {
    final t = await tasks.create(
      listId: work.id,
      title: 'Secret',
      notes: 'the code is 1234',
      tags: ['private'],
    );
    final sub = await subtasks.add(t.id, 'step');
    final photo = (await photos.add(PhotoParent.task, t.id, smallJpeg()))!;
    await tasks.delete(t.id);
    final tombstone = (await db.taskById(t.id))!;

    await bin.erase(t.id);

    final gone = (await db.taskById(t.id))!;
    expect(gone.title, '');
    expect(gone.notes, '');
    expect(gone.tags, isEmpty);
    expect(gone.deletedAt, erasedStamp(clock.node));
    expect(incomingWins(tombstone, gone), isTrue);
    final goneSub = (await db.subtaskById(sub.id))!;
    expect(goneSub.title, '');
    expect(goneSub.deletedAt, isNotNull);
    expect((await db.photoById(photo.id))!.deletedAt, isNotNull);
    expect(await store.get(photo.sha256), isNull);
    expect(await bin.watch().first, isEmpty);
  });
}
