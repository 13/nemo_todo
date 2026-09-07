import 'package:drift/drift.dart';
import 'package:nemo_core/nemo_core.dart';
import 'package:nemo_server/src/db/server_database.dart';
import 'package:nemo_server/src/sync/sync_log_writer.dart';

class SyncOutcome {
  const SyncOutcome({required this.response, required this.notifyUserIds});

  final SyncResponse response;

  /// Users whose lists changed and who should be poked to sync.
  final Set<String> notifyUserIds;
}

/// Applies a client's pushed changes and answers with everything the client
/// has not seen yet. See the design spec, "Sync protocol".
class SyncService {
  SyncService(
    this._db, {
    HlcClock? clock,
    DateTime Function()? now,
    this.pageSize = 500,
    this.maxSkew = const Duration(hours: 1),
  }) : _clock = clock ?? HlcClock(node: 'server'),
       _now = now ?? DateTime.now;

  final ServerDatabase _db;
  final HlcClock _clock;
  final DateTime Function() _now;
  final int pageSize;
  final Duration maxSkew;

  Future<SyncOutcome> sync(String userId, SyncRequest request) {
    return _db.transaction(() async {
      final roles = await _db.rolesOf(userId);
      final rejected = <RejectedChange>[];
      final touched = <String>{};
      for (final change in request.changes) {
        final reason = await _apply(userId, roles, change, touched);
        if (reason != null) {
          rejected.add(
            RejectedChange(
              entity: change.entity,
              rowId: change.rowId,
              reason: reason,
            ),
          );
        }
      }
      final page = await _pull(userId, roles.keys.toSet(), request.cursor);
      final members = await _db.membersOf(roles.keys);
      final notify = <String>{userId};
      for (final listId in touched) {
        notify.addAll(await _db.memberUserIds(listId));
      }
      return SyncOutcome(
        response: SyncResponse(
          changes: page.changes,
          rejected: rejected,
          members: members,
          cursor: page.cursor,
          hasMore: page.hasMore,
          serverHlc: _clock.now().toString(),
        ),
        notifyUserIds: notify,
      );
    });
  }

  /// Returns a rejection reason, or null when the change was accepted or
  /// was older than what the server already holds.
  Future<String?> _apply(
    String userId,
    Map<String, MemberRole> roles,
    SyncChange change,
    Set<String> touched,
  ) async {
    switch (change) {
      case SyncChangeList(:final row):
        final skew = _checkHlc(row.updatedAt);
        if (skew != null) return skew;
        final existing = await _db.listById(row.id);
        if (existing == null) {
          await _db
              .into(_db.lists)
              .insert(row.copyWith(ownerId: userId).toInsertable());
          await _db
              .into(_db.listMembers)
              .insert(
                ListMembersCompanion.insert(
                  listId: row.id,
                  userId: userId,
                  role: MemberRole.owner.name,
                ),
              );
          roles[row.id] = MemberRole.owner;
        } else {
          if (roles[row.id] != MemberRole.owner) return 'forbidden';
          if (!incomingWins(existing, row)) return null;
          await _db
              .into(_db.lists)
              .insertOnConflictUpdate(
                row.copyWith(ownerId: existing.ownerId).toInsertable(),
              );
        }
        _accept(row.updatedAt);
        await _db.logUpsert(SyncEntity.list, row.id, row.id);
        touched.add(row.id);
        return null;

      case SyncChangeTask(:final row):
        if (!roles.containsKey(row.listId)) return 'forbidden';
        final skew = _checkHlc(row.updatedAt);
        if (skew != null) return skew;
        final existing = await _db.taskById(row.id);
        final oldListId = existing?.listId;
        final moved = oldListId != null && oldListId != row.listId;
        if (moved && !roles.containsKey(oldListId)) return 'forbidden';
        if (!incomingWins(existing, row)) return null;
        await _db.into(_db.tasks).insertOnConflictUpdate(row.toInsertable());
        _accept(row.updatedAt);
        final subtasks = moved ? await _db.subtasksOfTask(row.id) : <Subtask>[];
        if (moved) {
          await _db.logRevoke(SyncEntity.task, row.id, listId: oldListId);
          for (final sub in subtasks) {
            await _db.logRevoke(SyncEntity.subtask, sub.id, listId: oldListId);
          }
          touched.add(oldListId);
        }
        await _db.logUpsert(SyncEntity.task, row.id, row.listId);
        for (final sub in subtasks) {
          await _db.logUpsert(SyncEntity.subtask, sub.id, row.listId);
        }
        touched.add(row.listId);
        return null;

      case SyncChangeSubtask(:final row):
        final task = await _db.taskById(row.taskId);
        if (task == null) return 'unknown_task';
        if (!roles.containsKey(task.listId)) return 'forbidden';
        final skew = _checkHlc(row.updatedAt);
        if (skew != null) return skew;
        final existing = await _db.subtaskById(row.id);
        if (!incomingWins(existing, row)) return null;
        await _db.into(_db.subtasks).insertOnConflictUpdate(row.toInsertable());
        _accept(row.updatedAt);
        await _db.logUpsert(SyncEntity.subtask, row.id, task.listId);
        touched.add(task.listId);
        return null;

      case SyncChangeRevoke():
        return 'not_allowed';
    }
  }

  String? _checkHlc(String updatedAt) {
    final Hlc hlc;
    try {
      hlc = Hlc.parse(updatedAt);
    } on FormatException {
      return 'invalid_hlc';
    }
    final limit = _now().millisecondsSinceEpoch + maxSkew.inMilliseconds;
    return hlc.millis > limit ? 'clock_skew' : null;
  }

  void _accept(String updatedAt) => _clock.receive(Hlc.parse(updatedAt));

  Future<({List<SyncChange> changes, int cursor, bool hasMore})> _pull(
    String userId,
    Set<String> listIds,
    int cursor,
  ) async {
    final query = _db.select(_db.syncLog)
      ..where((t) {
        final mine = t.forUserId.equals(userId);
        final visible = listIds.isEmpty
            ? mine
            : mine | (t.forUserId.isNull() & t.listId.isIn(listIds));
        return t.seq.isBiggerThanValue(cursor) & visible;
      })
      ..orderBy([(t) => OrderingTerm.asc(t.seq)])
      ..limit(pageSize + 1);
    final entries = await query.get();
    final hasMore = entries.length > pageSize;
    final page = hasMore ? entries.sublist(0, pageSize) : entries;
    if (page.isEmpty) {
      return (changes: <SyncChange>[], cursor: cursor, hasMore: false);
    }

    Set<String> idsFor(SyncEntity entity) => page
        .where((e) => e.op == 'upsert' && e.entity == entity.name)
        .map((e) => e.rowId)
        .toSet();
    final listRows = await _listsById(idsFor(SyncEntity.list));
    final taskRows = await _tasksById(idsFor(SyncEntity.task));
    final subtaskRows = await _subtasksById(idsFor(SyncEntity.subtask));

    final changes = <SyncChange>[];
    for (final entry in page) {
      final entity = SyncEntity.values.byName(entry.entity);
      if (entry.op == 'revoke') {
        changes.add(SyncChange.revoke(target: entity, id: entry.rowId));
        continue;
      }
      final change = switch (entity) {
        SyncEntity.list => _wrap(listRows[entry.rowId], SyncChange.list),
        SyncEntity.task => _wrap(taskRows[entry.rowId], SyncChange.task),
        SyncEntity.subtask => _wrap(
          subtaskRows[entry.rowId],
          SyncChange.subtask,
        ),
      };
      if (change != null) changes.add(change);
    }
    return (changes: changes, cursor: page.last.seq, hasMore: hasMore);
  }

  SyncChange? _wrap<T>(T? row, SyncChange Function(T) make) =>
      row == null ? null : make(row);

  Future<Map<String, TaskList>> _listsById(Set<String> ids) async {
    if (ids.isEmpty) return {};
    final rows = await (_db.select(
      _db.lists,
    )..where((t) => t.id.isIn(ids))).get();
    return {for (final r in rows) r.id: r};
  }

  Future<Map<String, Task>> _tasksById(Set<String> ids) async {
    if (ids.isEmpty) return {};
    final rows = await (_db.select(
      _db.tasks,
    )..where((t) => t.id.isIn(ids))).get();
    return {for (final r in rows) r.id: r};
  }

  Future<Map<String, Subtask>> _subtasksById(Set<String> ids) async {
    if (ids.isEmpty) return {};
    final rows = await (_db.select(
      _db.subtasks,
    )..where((t) => t.id.isIn(ids))).get();
    return {for (final r in rows) r.id: r};
  }
}
