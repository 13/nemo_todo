import 'package:drift/drift.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/row_lookups.dart';
import 'package:nemo_core/nemo_core.dart';

/// Returned for a queued row that is not ready to be pushed yet. It is not
/// sent and its queue entry is kept.
const _held = SyncChange.revoke(target: SyncEntity.photo, id: '__held__');

/// The queue of local edits waiting to be pushed.
extension SyncOutbox on AppDatabase {
  /// Queues every row, used when an account is connected.
  Future<void> enqueueAll() => transaction(() async {
    Future<void> add(SyncEntity entity, Iterable<SyncRow> rows) async {
      for (final row in rows) {
        await into(outbox).insertOnConflictUpdate(
          OutboxCompanion.insert(
            entity: entity.name,
            rowId: row.id,
            enqueuedUpdatedAt: row.updatedAt,
          ),
        );
      }
    }

    await add(SyncEntity.list, await select(lists).get());
    await add(SyncEntity.task, await select(tasks).get());
    await add(SyncEntity.subtask, await select(subtasks).get());
    await add(SyncEntity.photo, await select(photos).get());
    await add(SyncEntity.note, await select(notes).get());
  });

  /// The queued rows as they are right now.
  ///
  /// Without [includePhotos], photo entries -- upserts and tombstones alike
  /// -- are neither returned nor dropped. A server from before photos
  /// cannot decode one, and refuses the whole request over it, so a single
  /// deleted picture would stop every task from syncing too.
  ///
  /// Without [includeNotes], note entries are held back the same way, and
  /// so is a photo entry whose row hangs on a note: a server that cannot
  /// read notes has nowhere to resolve that picture's parent either, and
  /// would refuse the whole push over it.
  Future<List<SyncChange>> outboxChanges({
    required bool includePhotos,
    required bool includeNotes,
  }) async {
    final entries = await select(outbox).get();
    final changes = <SyncChange>[];
    for (final entry in entries) {
      final entity = SyncEntity.values.byName(entry.entity);
      if (entity == SyncEntity.photo && !includePhotos) continue;
      if (entity == SyncEntity.note && !includeNotes) continue;
      final change = switch (entity) {
        SyncEntity.list => (await listById(entry.rowId)).let(SyncChange.list),
        SyncEntity.task => (await taskById(entry.rowId)).let(SyncChange.task),
        SyncEntity.subtask => (await subtaskById(
          entry.rowId,
        )).let(SyncChange.subtask),
        SyncEntity.photo => await _pushablePhoto(
          entry.rowId,
          includeNotes: includeNotes,
        ),
        SyncEntity.note => (await noteById(entry.rowId)).let(SyncChange.note),
      };
      if (identical(change, _held)) continue;
      if (change == null) {
        await (delete(outbox)..where(
              (t) =>
                  t.entity.equals(entry.entity) & t.rowId.equals(entry.rowId),
            ))
            .go();
      } else {
        changes.add(change);
      }
    }
    return changes;
  }

  /// A photo row is only offered to the server once the server has its
  /// bytes. Pushing it first would leave every other device holding a row
  /// it cannot fetch a picture for.
  ///
  /// A photo hanging on a note is held back the same way, not dropped, when
  /// [includeNotes] is false: the row still exists locally and the server
  /// may yet learn to read notes, at which point the still-queued entry is
  /// exactly what should go out.
  Future<SyncChange?> _pushablePhoto(
    String rowId, {
    required bool includeNotes,
  }) async {
    final row = await photoById(rowId);
    if (row == null) return null;
    if (!includeNotes && row.parentKind == PhotoParent.note) return _held;
    final blob = await (select(
      blobs,
    )..where((t) => t.sha256.equals(row.sha256))).getSingleOrNull();
    if (blob != null && blob.state != 'synced') return _held;
    return SyncChange.photo(row);
  }

  /// Removes queue entries for [pushed] rows unless edited since the push.
  Future<void> ackOutbox(Iterable<SyncChange> pushed) => transaction(() async {
    for (final change in pushed) {
      final updatedAt = switch (change) {
        SyncChangeList(:final row) => row.updatedAt,
        SyncChangeTask(:final row) => row.updatedAt,
        SyncChangeSubtask(:final row) => row.updatedAt,
        SyncChangePhoto(:final row) => row.updatedAt,
        SyncChangeNote(:final row) => row.updatedAt,
        SyncChangeRevoke() => null,
      };
      if (updatedAt == null) continue;
      await (delete(outbox)..where(
            (t) =>
                t.entity.equals(change.entity.name) &
                t.rowId.equals(change.rowId) &
                t.enqueuedUpdatedAt.equals(updatedAt),
          ))
          .go();
    }
  });

  /// Drops the queue entry for a row: the server refused the change, or its
  /// own row won and superseded what was queued. Either way the entry has to
  /// go, because [ackOutbox] only clears entries whose stamp still matches
  /// the one recorded when they were enqueued, so a superseded entry would
  /// otherwise be pushed on every round for the life of the install.
  Future<void> dropOutbox(SyncEntity entity, String rowId) => (delete(
    outbox,
  )..where((t) => t.entity.equals(entity.name) & t.rowId.equals(rowId))).go();

  Stream<int> watchOutboxCount() => customSelect(
    'select count(*) as c from outbox',
    readsFrom: {outbox},
  ).watchSingle().map((r) => r.read<int>('c'));

  Future<int> outboxCount() async => (await customSelect(
    'select count(*) as c from outbox',
  ).getSingle()).read<int>('c');

  Future<void> clearOutbox() => delete(outbox).go();
}

extension<T> on T? {
  R? let<R>(R Function(T) f) {
    final self = this;
    return self == null ? null : f(self);
  }
}
