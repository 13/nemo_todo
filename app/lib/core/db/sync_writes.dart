import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo_core/nemo_core.dart';

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
          await (delete(outbox)..where(
                (t) =>
                    (t.entity.equals(SyncEntity.task.name) &
                        t.rowId.isIn(taskIds)) |
                    (t.entity.equals(SyncEntity.subtask.name) &
                        t.rowId.isIn(subtaskIds)),
              ))
              .go();
          await (delete(subtasks)..where((t) => t.taskId.isIn(taskIds))).go();
        }
        await (delete(tasks)..where((t) => t.listId.equals(id))).go();
        await (delete(lists)..where((t) => t.id.equals(id))).go();
        await (delete(listMeta)..where((t) => t.listId.equals(id))).go();
      case SyncEntity.task:
        final subtaskIds = (await (select(
          subtasks,
        )..where((t) => t.taskId.equals(id))).get()).map((s) => s.id);
        await (delete(outbox)..where(
              (t) =>
                  t.entity.equals(SyncEntity.subtask.name) &
                  t.rowId.isIn(subtaskIds),
            ))
            .go();
        await (delete(subtasks)..where((t) => t.taskId.equals(id))).go();
        await (delete(tasks)..where((t) => t.id.equals(id))).go();
      case SyncEntity.subtask:
        await (delete(subtasks)..where((t) => t.id.equals(id))).go();
    }
    await (delete(
      outbox,
    )..where((t) => t.entity.equals(target.name) & t.rowId.equals(id))).go();
  }

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
  });

  /// The queued rows as they are right now.
  Future<List<SyncChange>> outboxChanges() async {
    final entries = await select(outbox).get();
    final changes = <SyncChange>[];
    for (final entry in entries) {
      final entity = SyncEntity.values.byName(entry.entity);
      final change = switch (entity) {
        SyncEntity.list => (await listById(entry.rowId)).let(SyncChange.list),
        SyncEntity.task => (await taskById(entry.rowId)).let(SyncChange.task),
        SyncEntity.subtask => (await subtaskById(
          entry.rowId,
        )).let(SyncChange.subtask),
      };
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

  /// Removes queue entries for [pushed] rows unless edited since the push.
  Future<void> ackOutbox(Iterable<SyncChange> pushed) => transaction(() async {
    for (final change in pushed) {
      final updatedAt = switch (change) {
        SyncChangeList(:final row) => row.updatedAt,
        SyncChangeTask(:final row) => row.updatedAt,
        SyncChangeSubtask(:final row) => row.updatedAt,
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

  /// Replaces sharing metadata with what the server reported.
  Future<void> setListMeta(
    Map<String, List<ListMember>> members,
    String myUsername,
  ) => transaction(() async {
    await delete(listMeta).go();
    for (final entry in members.entries) {
      final mine = entry.value
          .where((m) => m.username == myUsername)
          .map((m) => m.role.name)
          .firstOrNull;
      await into(listMeta).insert(
        ListMetaCompanion.insert(
          listId: entry.key,
          myRole: Value(mine),
          membersJson: Value(
            jsonEncode([for (final m in entry.value) m.toJson()]),
          ),
        ),
      );
    }
  });

  Future<void> clearListMeta() => delete(listMeta).go();

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
    await delete(subtasks).go();
    await delete(tasks).go();
    await delete(lists).go();
  });

  Stream<Map<String, ListSharing>> watchListMeta() => select(listMeta)
      .watch()
      .map((rows) => {for (final r in rows) r.listId: ListSharing.fromRow(r)});

  Future<TaskList?> listById(String id) =>
      (select(lists)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Task?> taskById(String id) =>
      (select(tasks)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Subtask?> subtaskById(String id) =>
      (select(subtasks)..where((t) => t.id.equals(id))).getSingleOrNull();
}

extension<T> on T? {
  R? let<R>(R Function(T) f) {
    final self = this;
    return self == null ? null : f(self);
  }
}

/// What we know offline about a list's sharing.
class ListSharing {
  const ListSharing({required this.myRole, required this.members});

  factory ListSharing.fromRow(ListMetaRow row) => ListSharing(
    myRole: MemberRole.values.asNameMap()[row.myRole],
    members: (jsonDecode(row.membersJson) as List<dynamic>)
        .map((e) => ListMember.fromJson(e as Map<String, dynamic>))
        .toList(),
  );

  /// Null while the list has never been reported by a server.
  final MemberRole? myRole;
  final List<ListMember> members;

  bool get isShared => members.length > 1;
  bool get isOwner => myRole == null || myRole == MemberRole.owner;
}
