import 'package:drift/drift.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo_core/nemo_core.dart';

class SubtasksRepository {
  SubtasksRepository(this._db, this._clock, this._newId);

  final AppDatabase _db;
  final HlcClock _clock;
  final String Function() _newId;

  Stream<List<Subtask>> watchByTask(String taskId) =>
      (_db.select(_db.subtasks)
            ..where((t) => t.taskId.equals(taskId) & t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.asc(t.sortKey)]))
          .watch();

  /// Progress of a task's checklist as (done, total).
  Stream<Map<String, ({int done, int total})>> watchProgress() =>
      (_db.select(
        _db.subtasks,
      )..where((t) => t.deletedAt.isNull())).watch().map((rows) {
        final result = <String, ({int done, int total})>{};
        for (final s in rows) {
          final current = result[s.taskId] ?? (done: 0, total: 0);
          result[s.taskId] = (
            done: current.done + (s.done ? 1 : 0),
            total: current.total + 1,
          );
        }
        return result;
      });

  Future<Subtask> add(String taskId, String title) async {
    final last =
        await (_db.select(_db.subtasks)
              ..where((t) => t.taskId.equals(taskId) & t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.desc(t.sortKey)])
              ..limit(1))
            .getSingleOrNull();
    final subtask = Subtask(
      id: _newId(),
      taskId: taskId,
      title: title.trim(),
      sortKey: last == null ? SortKey.first() : SortKey.after(last.sortKey),
      updatedAt: _clock.now().toString(),
    );
    await _db.upsertSubtask(subtask);
    return subtask;
  }

  Future<void> save(Subtask subtask) =>
      _db.upsertSubtask(subtask.copyWith(updatedAt: _clock.now().toString()));

  Future<void> delete(String id) async {
    final subtask = await _db.subtaskById(id);
    if (subtask == null) return;
    final stamp = _clock.now().toString();
    await _db.upsertSubtask(
      subtask.copyWith(updatedAt: stamp, deletedAt: stamp),
    );
  }

  Future<void> placeBetween(String id, {String? before, String? after}) async {
    final subtask = await _db.subtaskById(id);
    if (subtask == null) return;
    final prev = before == null
        ? null
        : (await _db.subtaskById(before))?.sortKey;
    final next = after == null ? null : (await _db.subtaskById(after))?.sortKey;
    if (prev != null && next != null && prev.compareTo(next) >= 0) return;
    await save(subtask.copyWith(sortKey: SortKey.between(prev, next)));
  }
}
