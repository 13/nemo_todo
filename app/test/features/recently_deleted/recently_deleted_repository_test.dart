import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/features/lists/data/lists_repository.dart';
import 'package:nemo/features/notes/data/notes_repository.dart';
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

  test('a deleted list is there with its tasks, not beside them', () async {
    final earlier = await tasks.create(listId: work.id, title: 'Before');
    await tasks.create(listId: work.id, title: 'In work');
    await tasks.create(listId: work.id, title: 'Also in work');
    await tasks.delete(earlier.id);
    await lists.delete(work.id);

    final shownLists = await bin.watchLists().first;
    expect(shownLists.single.list.id, work.id);
    expect(shownLists.single.tasks, 2, reason: 'the ones deleted with it');

    final shown = await bin.watch().first;
    expect(
      shown.single.task.id,
      earlier.id,
      reason: 'deleted on its own, before; restoring the list leaves it',
    );
    expect(shown.single.list, isNull, reason: 'it goes back to the Inbox');
  });

  group('lists nobody deleted, or not ours to bring back', () {
    test('an Inbox folded into another is not listed', () async {
      // As sync lands it: a second device's Inbox, folded away.
      await db.upsertList(
        TaskList(
          id: 'z-other-inbox',
          name: 'Inbox',
          sortKey: SortKey.first(),
          isInbox: true,
          icon: 'inbox',
          updatedAt: clock.now().toString(),
        ),
      );
      await lists.mergeDuplicateInboxes();
      expect((await db.listById('z-other-inbox'))!.isDeleted, isTrue);

      expect(await bin.watchLists().first, isEmpty);
    });

    test('nor one an older version folded away', () async {
      // Older versions cleared the flag on the Inbox they folded; its icon,
      // which no other list can take, still gives it away.
      final stamp = clock.now().toString();
      await db.upsertList(
        TaskList(
          id: 'z-other-inbox',
          name: 'Inbox',
          sortKey: SortKey.first(),
          icon: 'inbox',
          updatedAt: stamp,
          deletedAt: stamp,
        ),
      );

      expect(await bin.watchLists().first, isEmpty);
    });

    test('a shared list someone else deleted is not ours to restore', () async {
      final t = await tasks.create(listId: work.id, title: 'Theirs');
      await lists.delete(work.id);
      await db.setListMeta({
        work.id: const [
          ListMember(username: 'owner', role: MemberRole.owner),
          ListMember(username: 'me', role: MemberRole.editor),
        ],
      }, 'me');

      expect(await bin.watchLists().first, isEmpty);
      final shown = await bin.watch().first;
      expect(
        shown.single.task.id,
        t.id,
        reason: 'its tasks can still come back, into the Inbox',
      );
    });

    test('nor one deleted before the window', () async {
      final past = ListsRepository(
        db,
        HlcClock(
          node: 'past',
          now: () => testNow.subtract(const Duration(days: 31)),
        ),
        sequentialIds('past'),
      );
      final old = await past.create(name: 'Long gone');
      await past.delete(old.id);

      expect(await bin.watchLists().first, isEmpty);
    });
  });

  test('restoring a list brings back what went with it, queued', () async {
    final notes = NotesRepository(db, clock, sequentialIds('note'));
    final earlier = await tasks.create(listId: work.id, title: 'Before');
    final t = await tasks.create(listId: work.id, title: 'In work');
    final sub = await subtasks.add(t.id, 'step');
    final note = await notes.create(listId: work.id, title: 'Plan');
    await tasks.delete(earlier.id);
    await lists.delete(work.id);
    final tombstone = (await db.listById(work.id))!;
    await db.clearOutbox();

    final back = await bin.restoreList(work.id);

    expect(back?.id, work.id);
    final list = (await db.listById(work.id))!;
    expect(list.deletedAt, isNull);
    expect(incomingWins(tombstone, list), isTrue);
    expect((await db.taskById(t.id))!.deletedAt, isNull);
    expect((await db.subtaskById(sub.id))!.deletedAt, isNull);
    expect((await db.noteById(note.id))!.deletedAt, isNull);
    expect((await db.taskById(earlier.id))!.deletedAt, isNotNull);
    expect(await db.outboxCount(), 4, reason: 'list, task, subtask, note');
    expect(await bin.watchLists().first, isEmpty);
    expect(
      (await bin.watch().first).single.list?.id,
      work.id,
      reason: 'the task deleted before now goes back to the list',
    );
  });

  test('delete now erases a list and everything in it', () async {
    final notes = NotesRepository(db, clock, sequentialIds('note'));
    final earlier = await tasks.create(listId: work.id, title: 'Before');
    final t = await tasks.create(listId: work.id, title: 'Secret');
    final sub = await subtasks.add(t.id, 'step');
    final photo = (await photos.add(PhotoParent.task, t.id, smallJpeg()))!;
    final note = await notes.create(
      listId: work.id,
      title: 'Plan',
      body: 'the code is 1234',
    );
    final notePhoto = (await photos.add(
      PhotoParent.note,
      note.id,
      smallJpeg(width: 24),
    ))!;
    await tasks.delete(earlier.id);
    await lists.delete(work.id);
    final tombstone = (await db.listById(work.id))!;

    await bin.eraseList(work.id);

    final gone = (await db.listById(work.id))!;
    expect(gone.name, '');
    expect(gone.deletedAt, erasedStamp(clock.node));
    expect(incomingWins(tombstone, gone), isTrue);
    for (final id in [earlier.id, t.id]) {
      final task = (await db.taskById(id))!;
      expect(task.title, '');
      expect(task.deletedAt, erasedStamp(clock.node));
    }
    expect((await db.subtaskById(sub.id))!.title, '');
    final goneNote = (await db.noteById(note.id))!;
    expect(goneNote.title, '');
    expect(goneNote.body, '');
    expect(goneNote.deletedAt, erasedStamp(clock.node));
    expect((await db.photoById(photo.id))!.deletedAt, isNotNull);
    expect((await db.photoById(notePhoto.id))!.deletedAt, isNotNull);
    expect(await store.get(photo.sha256), isNull);
    expect(await store.get(notePhoto.sha256), isNull);
    expect(await bin.watchLists().first, isEmpty);
    expect(await bin.watch().first, isEmpty);
  });

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
