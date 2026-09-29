import 'package:drift/drift.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/db/row_lookups.dart';
import 'package:nemo/core/db/sync_outbox.dart';
import 'package:nemo_core/nemo_core.dart';

export 'package:nemo/core/db/list_sharing.dart';
export 'package:nemo/core/db/row_lookups.dart';
export 'package:nemo/core/db/sync_blobs.dart';
export 'package:nemo/core/db/sync_outbox.dart';

/// Local mutations and remote application, both keeping the outbox honest.
extension SyncWrites on AppDatabase {
  /// Writes a locally edited list and queues it for the next sync.
  Future<void> upsertList(TaskList row) => _writeLocal(
    SyncEntity.list,
    row,
    () => into(lists).insertOnConflictUpdate(row.toInsertable()),
  );

  Future<void> upsertTask(Task row) => _writeLocal(
    SyncEntity.task,
    row,
    () => into(tasks).insertOnConflictUpdate(row.toInsertable()),
  );

  Future<void> upsertSubtask(Subtask row) => _writeLocal(
    SyncEntity.subtask,
    row,
    () => into(subtasks).insertOnConflictUpdate(row.toInsertable()),
  );

  Future<void> upsertPhoto(Photo row) => _writeLocal(
    SyncEntity.photo,
    row,
    () => into(photos).insertOnConflictUpdate(row.toInsertable()),
  );

  Future<void> upsertNote(Note row) => _writeLocal(
    SyncEntity.note,
    row,
    () => into(notes).insertOnConflictUpdate(row.toInsertable()),
  );

  Future<void> _writeLocal(
    SyncEntity entity,
    SyncRow row,
    Future<void> Function() write,
  ) => transaction(() async {
    await write();
    await into(outbox).insertOnConflictUpdate(
      OutboxCompanion.insert(
        entity: entity.name,
        rowId: row.id,
        enqueuedUpdatedAt: row.updatedAt,
      ),
    );
    await into(kv).insertOnConflictUpdate(
      KvCompanion.insert(key: KvKeys.hlcLast, value: Value(row.updatedAt)),
    );
  });

  /// Applies a server change with last-write-wins, clearing any queued
  /// edit the incoming row supersedes. Returns the task that was written,
  /// if any, so reminders can be rescheduled.
  Future<Task?> applyRemote(SyncChange change) => transaction(() async {
    switch (change) {
      case SyncChangeList(:final row):
        final local = await listById(row.id);
        if (incomingWins(local, row)) {
          await into(lists).insertOnConflictUpdate(row.toInsertable());
          await dropOutbox(SyncEntity.list, row.id);
        }
        return null;
      case SyncChangeTask(:final row):
        final local = await taskById(row.id);
        if (!incomingWins(local, row)) return null;
        await into(tasks).insertOnConflictUpdate(row.toInsertable());
        await dropOutbox(SyncEntity.task, row.id);
        return row;
      case SyncChangeSubtask(:final row):
        final local = await subtaskById(row.id);
        if (incomingWins(local, row)) {
          await into(subtasks).insertOnConflictUpdate(row.toInsertable());
          await dropOutbox(SyncEntity.subtask, row.id);
        }
        return null;
      case SyncChangePhoto(:final row):
        final local = await photoById(row.id);
        if (incomingWins(local, row)) {
          await into(photos).insertOnConflictUpdate(row.toInsertable());
          await dropOutbox(SyncEntity.photo, row.id);
        }
        return null;
      case SyncChangeNote(:final row):
        final local = await noteById(row.id);
        if (incomingWins(local, row)) {
          await into(notes).insertOnConflictUpdate(row.toInsertable());
          await dropOutbox(SyncEntity.note, row.id);
        }
        return null;
      case SyncChangeRevoke(:final target, :final id):
        await _revoke(target, id);
        return null;
    }
  });

  Future<void> _revoke(SyncEntity target, String id) async {
    switch (target) {
      case SyncEntity.list:
        final taskIds = (await (select(
          tasks,
        )..where((t) => t.listId.equals(id))).get()).map((t) => t.id).toList();
        if (taskIds.isNotEmpty) {
          final subtaskIds = (await (select(
            subtasks,
          )..where((t) => t.taskId.isIn(taskIds))).get()).map((s) => s.id);
          final photoIds =
              (await (select(photos)..where(
                        (t) =>
                            t.parentKind.equalsValue(PhotoParent.task) &
                            t.parentId.isIn(taskIds),
                      ))
                      .get())
                  .map((p) => p.id);
          await (delete(outbox)..where(
                (t) =>
                    (t.entity.equals(SyncEntity.task.name) &
                        t.rowId.isIn(taskIds)) |
                    (t.entity.equals(SyncEntity.subtask.name) &
                        t.rowId.isIn(subtaskIds)) |
                    (t.entity.equals(SyncEntity.photo.name) &
                        t.rowId.isIn(photoIds)),
              ))
              .go();
          await (delete(subtasks)..where((t) => t.taskId.isIn(taskIds))).go();
          await (delete(photos)..where(
                (t) =>
                    t.parentKind.equalsValue(PhotoParent.task) &
                    t.parentId.isIn(taskIds),
              ))
              .go();
        }
        // A note left behind here would orphan: nothing else ever notices
        // that its list is gone, and the picture it carries would sit in
        // this device's database for good.
        final noteIds = (await (select(
          notes,
        )..where((t) => t.listId.equals(id))).get()).map((n) => n.id).toList();
        if (noteIds.isNotEmpty) {
          final notePhotoIds =
              (await (select(photos)..where(
                        (t) =>
                            t.parentKind.equalsValue(PhotoParent.note) &
                            t.parentId.isIn(noteIds),
                      ))
                      .get())
                  .map((p) => p.id);
          await (delete(outbox)..where(
                (t) =>
                    (t.entity.equals(SyncEntity.note.name) &
                        t.rowId.isIn(noteIds)) |
                    (t.entity.equals(SyncEntity.photo.name) &
                        t.rowId.isIn(notePhotoIds)),
              ))
              .go();
          await (delete(photos)..where(
                (t) =>
                    t.parentKind.equalsValue(PhotoParent.note) &
                    t.parentId.isIn(noteIds),
              ))
              .go();
        }
        await (delete(tasks)..where((t) => t.listId.equals(id))).go();
        await (delete(notes)..where((t) => t.listId.equals(id))).go();
        await (delete(lists)..where((t) => t.id.equals(id))).go();
        await (delete(listMeta)..where((t) => t.listId.equals(id))).go();
      case SyncEntity.task:
        final subtaskIds = (await (select(
          subtasks,
        )..where((t) => t.taskId.equals(id))).get()).map((s) => s.id);
        final photoIds =
            (await (select(photos)..where(
                      (t) =>
                          t.parentKind.equalsValue(PhotoParent.task) &
                          t.parentId.equals(id),
                    ))
                    .get())
                .map((p) => p.id);
        await (delete(outbox)..where(
              (t) =>
                  (t.entity.equals(SyncEntity.subtask.name) &
                      t.rowId.isIn(subtaskIds)) |
                  (t.entity.equals(SyncEntity.photo.name) &
                      t.rowId.isIn(photoIds)),
            ))
            .go();
        await (delete(subtasks)..where((t) => t.taskId.equals(id))).go();
        await (delete(photos)..where(
              (t) =>
                  t.parentKind.equalsValue(PhotoParent.task) &
                  t.parentId.equals(id),
            ))
            .go();
        await (delete(tasks)..where((t) => t.id.equals(id))).go();
      case SyncEntity.subtask:
        await (delete(subtasks)..where((t) => t.id.equals(id))).go();
      case SyncEntity.photo:
        await (delete(photos)..where((t) => t.id.equals(id))).go();
      case SyncEntity.note:
        final photoIds =
            (await (select(photos)..where(
                      (t) =>
                          t.parentKind.equalsValue(PhotoParent.note) &
                          t.parentId.equals(id),
                    ))
                    .get())
                .map((p) => p.id);
        await (delete(outbox)..where(
              (t) =>
                  t.entity.equals(SyncEntity.photo.name) &
                  t.rowId.isIn(photoIds),
            ))
            .go();
        await (delete(photos)..where(
              (t) =>
                  t.parentKind.equalsValue(PhotoParent.note) &
                  t.parentId.equals(id),
            ))
            .go();
        await (delete(notes)..where((t) => t.id.equals(id))).go();
    }
    await (delete(
      outbox,
    )..where((t) => t.entity.equals(target.name) & t.rowId.equals(id))).go();
  }

  /// Empties every table holding someone's tasks, leaving the key-value
  /// store -- the node id and the theme are this device's, not an
  /// account's.
  ///
  /// Only where an account is required to see anything at all: signing out
  /// there means the next person to sign in starts from the server, not
  /// from whatever the last one left in the browser, and certainly not by
  /// uploading it to their own account.
  Future<void> clearLocalData() => transaction(() async {
    await delete(outbox).go();
    await delete(listMeta).go();
    await delete(photos).go();
    await delete(blobs).go();
    await delete(subtasks).go();
    await delete(tasks).go();
    await delete(notes).go();
    await delete(lists).go();
  });
}
