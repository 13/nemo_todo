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

/// Tasks deleted in the last [tombstoneRetention]: listing them, bringing
/// one back, or deleting one for good at once.
///
/// Every deleted task is still a row here -- a tombstone, which is how the
/// deletion reached the other devices -- until the server's purge retires
/// it. So nothing is kept for this page that was not kept anyway.
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

  /// Tasks deleted within the window, the most recently deleted first.
  Stream<List<DeletedTask>> watch() {
    final cutoff = tombstoneCutoff(_now());
    final query =
        _db.select(_db.tasks).join([
            leftOuterJoin(
              _db.lists,
              _db.lists.id.equalsExp(_db.tasks.listId) &
                  _db.lists.deletedAt.isNull(),
            ),
          ])
          ..where(_db.tasks.deletedAt.isBiggerOrEqualValue(cutoff))
          ..orderBy([OrderingTerm.desc(_db.tasks.deletedAt)]);
    return query.watch().map(
      (rows) => [
        for (final r in rows)
          (task: r.readTable(_db.tasks), list: r.readTableOrNull(_db.lists)),
      ],
    );
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
    )..where((t) => t.taskId.equals(id))).get();
    for (final sub in subtasks) {
      await _db.upsertSubtask(
        sub.copyWith(
          title: '',
          deletedAt: erased,
          updatedAt: _clock.now().toString(),
        ),
      );
    }
    final pictures =
        await (_db.select(_db.photos)..where(
              (t) =>
                  t.parentKind.equalsValue(PhotoParent.task) &
                  t.parentId.equals(id),
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
