import 'package:drift/drift.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo_core/nemo_core.dart';

/// Lists: reads are streams over the local database, writes stamp an HLC
/// and queue the row for sync.
class ListsRepository {
  ListsRepository(
    this._db,
    this._clock,
    this._newId, {
    this.reminders = const NoopReminderScheduler(),
  });

  final AppDatabase _db;
  final HlcClock _clock;
  final String Function() _newId;

  /// Deleting a list has to cancel the reminders of the tasks it takes
  /// with it, so the repository holds the scheduler the way the task
  /// repository does.
  final ReminderScheduler reminders;

  /// Inbox first, then by sort key; tombstones hidden.
  Stream<List<TaskList>> watchAll() =>
      (_db.select(_db.lists)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([
              (t) => OrderingTerm.desc(t.isInbox),
              (t) => OrderingTerm.asc(t.sortKey),
            ]))
          .watch();

  Stream<TaskList?> watch(String id) => (_db.select(
    _db.lists,
  )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).watchSingleOrNull();

  /// Creates the Inbox on first launch; harmless afterwards.
  Future<TaskList> ensureInbox() async {
    final existing =
        await (_db.select(_db.lists)
              ..where((t) => t.isInbox.equals(true) & t.deletedAt.isNull()))
            .getSingleOrNull();
    if (existing != null) return existing;
    final inbox = TaskList(
      id: _newId(),
      name: 'Inbox',
      sortKey: SortKey.first(),
      isInbox: true,
      icon: 'inbox',
      updatedAt: _clock.now().toString(),
    );
    await _db.upsertList(inbox);
    return inbox;
  }

  Future<TaskList> create({
    required String name,
    int color = 0,
    String icon = 'list',
  }) async {
    final last =
        await (_db.select(_db.lists)
              ..where((t) => t.deletedAt.isNull() & t.isInbox.equals(false))
              ..orderBy([(t) => OrderingTerm.desc(t.sortKey)])
              ..limit(1))
            .getSingleOrNull();
    final list = TaskList(
      id: _newId(),
      name: name.trim(),
      color: color,
      icon: icon,
      sortKey: last == null ? SortKey.first() : SortKey.after(last.sortKey),
      updatedAt: _clock.now().toString(),
    );
    await _db.upsertList(list);
    return list;
  }

  Future<void> save(TaskList list) =>
      _db.upsertList(list.copyWith(updatedAt: _clock.now().toString()));

  /// Tombstones the list and everything in it.
  ///
  /// The tasks used to be left alive and merely hidden behind the deleted
  /// list. Hidden is not deleted: their reminders stayed scheduled, so a
  /// deleted list went on posting notifications for tasks nobody could see
  /// or open. Every row the cascade takes down carries the list's own
  /// stamp, which is what lets [restore] revive exactly those rows and not
  /// the ones deleted before them.
  Future<void> delete(String id) async {
    final list = await _db.listById(id);
    if (list == null || list.isInbox) return;
    final stamp = _clock.now().toString();
    await _db.upsertList(list.copyWith(updatedAt: stamp, deletedAt: stamp));
    for (final task in await _liveTasks(id)) {
      final deleted = task.copyWith(updatedAt: stamp, deletedAt: stamp);
      await _db.upsertTask(deleted);
      await reminders.sync(deleted);
      for (final sub in await _liveSubtasks(task.id)) {
        await _db.upsertSubtask(
          sub.copyWith(updatedAt: stamp, deletedAt: stamp),
        );
      }
    }
  }

  /// Brings the list back, along with whatever went down with it.
  Future<void> restore(String id) async {
    final list = await _db.listById(id);
    if (list == null) return;
    final tombstone = list.deletedAt;
    await _db.upsertList(
      list.copyWith(updatedAt: _clock.now().toString(), deletedAt: null),
    );
    if (tombstone == null) return;
    for (final task in await _tasksDeletedAt(id, tombstone)) {
      final restored = task.copyWith(
        updatedAt: _clock.now().toString(),
        deletedAt: null,
      );
      await _db.upsertTask(restored);
      await reminders.sync(restored);
      for (final sub in await _subtasksDeletedAt(task.id, tombstone)) {
        await _db.upsertSubtask(
          sub.copyWith(updatedAt: _clock.now().toString(), deletedAt: null),
        );
      }
    }
  }

  Future<List<Task>> _liveTasks(String listId) => (_db.select(
    _db.tasks,
  )..where((t) => t.listId.equals(listId) & t.deletedAt.isNull())).get();

  Future<List<Subtask>> _liveSubtasks(String taskId) => (_db.select(
    _db.subtasks,
  )..where((t) => t.taskId.equals(taskId) & t.deletedAt.isNull())).get();

  Future<List<Task>> _tasksDeletedAt(String listId, String stamp) =>
      (_db.select(_db.tasks)
            ..where((t) => t.listId.equals(listId) & t.deletedAt.equals(stamp)))
          .get();

  Future<List<Subtask>> _subtasksDeletedAt(String taskId, String stamp) =>
      (_db.select(_db.subtasks)
            ..where((t) => t.taskId.equals(taskId) & t.deletedAt.equals(stamp)))
          .get();
}
