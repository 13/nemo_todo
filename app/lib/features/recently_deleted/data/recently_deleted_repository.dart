import 'package:drift/drift.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/features/lists/data/lists_repository.dart';
import 'package:nemo/features/photos/data/photo_store.dart';
import 'package:nemo/features/tasks/data/tasks_repository.dart';
import 'package:nemo_core/nemo_core.dart';

/// A deleted task and the live list it would go back to, or null when that
/// list is deleted or gone and it would go to the Inbox instead.
typedef DeletedTask = ({Task task, TaskList? list});

/// A deleted list and how many tasks went down with it.
typedef DeletedList = ({TaskList list, int tasks});

/// Lists and tasks deleted in the last [tombstoneRetention]: listing them,
/// bringing one back, or deleting one for good at once.
///
/// Every deleted row is still a row here -- a tombstone, which is how the
/// deletion reached the other devices -- until the server's purge retires
/// it. So nothing is kept for this page that was not kept anyway.
///
/// A list is offered back when someone deleted it and this account owns
/// it; an Inbox folded into another (see [ListsRepository.isFoldedInbox])
/// was never deleted by anyone, and a shared list is its owner's to bring
/// back -- the server takes a list row from no one else. The tasks that
/// went down with a list offered here are part of it, not listed beside
/// it; those of a list that is not offered are listed one by one, and go
/// back to the Inbox.
class RecentlyDeletedRepository {
  RecentlyDeletedRepository(
    this._db,
    this._clock, {
    required this.lists,
    required this.tasks,
    required this._store,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final AppDatabase _db;
  final HlcClock _clock;
  final ListsRepository lists;
  final TasksRepository tasks;
  final PhotoStore _store;
  final DateTime Function() _now;

  /// Tasks deleted within the window, the most recently deleted first,
  /// leaving out those that went down with a list in [watchLists].
  Stream<List<DeletedTask>> watch() {
    final cutoff = tombstoneCutoff(_now());
    final query =
        _db.select(_db.tasks).join([
            leftOuterJoin(_db.lists, _db.lists.id.equalsExp(_db.tasks.listId)),
            leftOuterJoin(
              _db.listMeta,
              _db.listMeta.listId.equalsExp(_db.tasks.listId),
            ),
          ])
          ..where(_db.tasks.deletedAt.isBiggerOrEqualValue(cutoff))
          ..orderBy([OrderingTerm.desc(_db.tasks.deletedAt)]);
    return query.watch().map(
      (rows) => [for (final r in rows) ?_withList(r, cutoff)],
    );
  }

  /// [row] as a task to list on its own, or null when it went down with a
  /// list the page offers back whole.
  DeletedTask? _withList(TypedResult row, String cutoff) {
    final task = row.readTable(_db.tasks);
    final list = row.readTableOrNull(_db.lists);
    if (list == null || !list.isDeleted) return (task: task, list: list);
    final restorable = _restorable(
      list,
      row.readTableOrNull(_db.listMeta),
      cutoff,
    );
    if (restorable && task.deletedAt == list.deletedAt) return null;
    return (task: task, list: null);
  }

  /// Lists deleted within the window that this account can bring back, the
  /// most recently deleted first.
  Stream<List<DeletedList>> watchLists() {
    final cutoff = tombstoneCutoff(_now());
    final gone = _db.tasks.id.count();
    final query =
        _db.select(_db.lists).join([
            leftOuterJoin(
              _db.listMeta,
              _db.listMeta.listId.equalsExp(_db.lists.id),
            ),
            leftOuterJoin(
              _db.tasks,
              _db.tasks.listId.equalsExp(_db.lists.id) &
                  _db.tasks.deletedAt.equalsExp(_db.lists.deletedAt),
              useColumns: false,
            ),
          ])
          ..addColumns([gone])
          ..where(_db.lists.deletedAt.isBiggerOrEqualValue(cutoff))
          ..groupBy([_db.lists.id])
          ..orderBy([OrderingTerm.desc(_db.lists.deletedAt)]);
    return query.watch().map(
      (rows) => [
        for (final r in rows)
          if (_restorable(
            r.readTable(_db.lists),
            r.readTableOrNull(_db.listMeta),
            cutoff,
          ))
            (list: r.readTable(_db.lists), tasks: r.read(gone) ?? 0),
      ],
    );
  }

  /// Whether [list] is deleted within the window, by someone, and ours:
  /// the same rule as `ListSharing.isOwner`, where a list no server has
  /// reported yet is this device's own.
  bool _restorable(TaskList list, ListMetaRow? meta, String cutoff) {
    final deletedAt = list.deletedAt;
    return deletedAt != null &&
        deletedAt.compareTo(cutoff) >= 0 &&
        !ListsRepository.isFoldedInbox(list) &&
        (meta?.myRole == null || meta?.myRole == MemberRole.owner.name);
  }

  /// Brings the list [id] back with the tasks, subtasks and notes that went
  /// down with it, and returns it; null if it is not deleted.
  ///
  /// An ordinary edit of each row, as undoing the deletion is, so it syncs
  /// like any change. A shared list comes back shared: the server keeps
  /// who is on a list while it is deleted, so the others get it back too.
  Future<TaskList?> restoreList(String id) async {
    final list = await _db.listById(id);
    if (list == null || !list.isDeleted) return null;
    await lists.restore(id);
    return await _db.listById(id);
  }

  /// Deletes the list [id] for good, and everything in it, the way [erase]
  /// does a task.
  ///
  /// Everything means every task and note the list holds, not only those
  /// deleted with it: once the list is gone the server's purge takes all
  /// of its rows with it, so a task deleted from it earlier would vanish
  /// from this page at the next purge either way.
  Future<void> eraseList(String id) async {
    final list = await _db.listById(id);
    if (list == null || !list.isDeleted) return;
    final erased = erasedStamp(_clock.node);
    await _db.upsertList(
      list.copyWith(
        name: '',
        deletedAt: erased,
        updatedAt: _clock.now().toString(),
      ),
    );
    final held = await (_db.select(
      _db.tasks,
    )..where((t) => t.listId.equals(id))).get();
    for (final task in held) {
      await _eraseTask(task);
    }
    final notes = await (_db.select(
      _db.notes,
    )..where((t) => t.listId.equals(id))).get();
    for (final note in notes) {
      await _db.upsertNote(
        note.copyWith(
          title: '',
          body: '',
          deletedAt: erased,
          updatedAt: _clock.now().toString(),
        ),
      );
      await _erasePhotos(PhotoParent.note, note.id);
    }
  }

  /// Brings [id] back, into its own list or, if that is gone, the Inbox,
  /// and returns the list it went to.
  ///
  /// An ordinary edit with a fresh stamp, so it beats the tombstone on
  /// every device the way any later edit beats an earlier one. The
  /// subtasks that went down with it -- the ones carrying the same
  /// deletion stamp, as a list's deletion leaves them -- come back too;
  /// ones deleted on their own before it stay deleted. Photos and
  /// everything else on the task were never removed.
  Future<TaskList?> restore(String id) async {
    final task = await _db.taskById(id);
    final tombstone = task?.deletedAt;
    if (task == null || tombstone == null) return null;
    final own = await _db.listById(task.listId);
    final home = own != null && !own.isDeleted
        ? own
        : await lists.ensureInbox();
    await tasks.save(
      task.copyWith(
        deletedAt: null,
        listId: home.id,
        sortKey: home.id == task.listId
            ? task.sortKey
            : await tasks.nextSortKey(home.id),
      ),
    );
    final subtasks = await (_db.select(
      _db.subtasks,
    )..where((t) => t.taskId.equals(id) & t.deletedAt.equals(tombstone))).get();
    for (final sub in subtasks) {
      await _db.upsertSubtask(
        sub.copyWith(updatedAt: _clock.now().toString(), deletedAt: null),
      );
    }
    return home;
  }

  /// Deletes [id] for good, now rather than at the end of the window.
  ///
  /// The row cannot simply be removed: it is what tells the server and the
  /// other devices, and the outbox pushes rows as they are. So it is
  /// written once more with its text cleared, a fresh stamp that wins over
  /// the tombstone everywhere, and a deletion stamped at the epoch -- older
  /// than any window, so it leaves this page on every device at once and
  /// the server's next purge retires it. Its subtasks and photos go the
  /// same way, and a photo's bytes leave this device when nothing else
  /// names them.
  Future<void> erase(String id) async {
    final task = await _db.taskById(id);
    if (task == null || !task.isDeleted) return;
    await _eraseTask(task);
  }

  Future<void> _eraseTask(Task task) async {
    final erased = erasedStamp(_clock.node);
    final gone = task.copyWith(
      title: '',
      notes: '',
      solution: '',
      tags: const [],
      remind: false,
      deletedAt: erased,
      updatedAt: _clock.now().toString(),
    );
    await _db.upsertTask(gone);
    await tasks.reminders.sync(gone);
    final subtasks = await (_db.select(
      _db.subtasks,
    )..where((t) => t.taskId.equals(task.id))).get();
    for (final sub in subtasks) {
      await _db.upsertSubtask(
        sub.copyWith(
          title: '',
          deletedAt: erased,
          updatedAt: _clock.now().toString(),
        ),
      );
    }
    await _erasePhotos(PhotoParent.task, task.id);
  }

  /// Tombstones the pictures on [parentId] at the epoch, and removes their
  /// bytes from this device when nothing else names them.
  Future<void> _erasePhotos(PhotoParent kind, String parentId) async {
    final erased = erasedStamp(_clock.node);
    final pictures =
        await (_db.select(_db.photos)..where(
              (t) =>
                  t.parentKind.equalsValue(kind) & t.parentId.equals(parentId),
            ))
            .get();
    for (final photo in pictures) {
      await _db.upsertPhoto(
        photo.copyWith(deletedAt: erased, updatedAt: _clock.now().toString()),
      );
      if (await _db.forgetUnusedBlob(photo.sha256)) {
        await _store.remove(photo.sha256);
      }
    }
  }
}
