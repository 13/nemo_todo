import 'package:drift/drift.dart';
import 'package:nemo_core/nemo_core.dart';
import 'package:nemo_server/src/db/server_database.dart';

/// Change-log and membership queries shared by the sync and members
/// services. The log keeps one live row per (entity, row, op, scope); a
/// re-log deletes the old row so `seq` grows but the table does not.
extension SyncLogWriter on ServerDatabase {
  /// Re-logs a row for every member, or for [forUserId] alone when the row
  /// is only being handed back to one client.
  Future<void> logUpsert(
    SyncEntity entity,
    String rowId,
    String listId, {
    String? forUserId,
  }) async {
    await (delete(syncLog)..where((t) {
          final row =
              t.entity.equals(entity.name) &
              t.rowId.equals(rowId) &
              t.op.equals('upsert');
          // A re-log for everyone supersedes the entries addressed to one
          // user; a re-log for one user must leave the shared entry alone,
          // because the other members have not seen it yet.
          return forUserId == null ? row : row & t.forUserId.equals(forUserId);
        }))
        .go();
    await into(syncLog).insert(
      SyncLogCompanion.insert(
        entity: entity.name,
        rowId: rowId,
        listId: listId,
        op: 'upsert',
        forUserId: Value(forUserId),
      ),
    );
  }

  /// Tells members of [listId] (or only [forUserId]) to drop their copy.
  Future<void> logRevoke(
    SyncEntity entity,
    String rowId, {
    required String listId,
    String? forUserId,
  }) async {
    await (delete(syncLog)..where((t) {
          final scope = forUserId == null
              ? t.forUserId.isNull()
              : t.forUserId.equals(forUserId);
          return t.entity.equals(entity.name) &
              t.rowId.equals(rowId) &
              t.op.equals('revoke') &
              t.listId.equals(listId) &
              scope;
        }))
        .go();
    await into(syncLog).insert(
      SyncLogCompanion.insert(
        entity: entity.name,
        rowId: rowId,
        listId: listId,
        op: 'revoke',
        forUserId: Value(forUserId),
      ),
    );
  }

  Future<Map<String, MemberRole>> rolesOf(String userId) async {
    final rows = await (select(
      listMembers,
    )..where((t) => t.userId.equals(userId))).get();
    return {for (final r in rows) r.listId: MemberRole.values.byName(r.role)};
  }

  Future<Set<String>> memberUserIds(String listId) async {
    final rows = await (select(
      listMembers,
    )..where((t) => t.listId.equals(listId))).get();
    return rows.map((r) => r.userId).toSet();
  }

  Future<List<Task>> tasksOfList(String listId) =>
      (select(tasks)..where((t) => t.listId.equals(listId))).get();

  Future<List<Subtask>> subtasksOfTask(String taskId) =>
      (select(subtasks)..where((t) => t.taskId.equals(taskId))).get();

  Future<TaskList?> listById(String id) =>
      (select(lists)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Task?> taskById(String id) =>
      (select(tasks)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Subtask?> subtaskById(String id) =>
      (select(subtasks)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Members of every list in [listIds], owner first then by username.
  Future<Map<String, List<ListMember>>> membersOf(
    Iterable<String> listIds,
  ) async {
    final ids = listIds.toList();
    if (ids.isEmpty) return {};
    final query = select(listMembers).join([
      innerJoin(users, users.id.equalsExp(listMembers.userId)),
    ])..where(listMembers.listId.isIn(ids));
    final result = <String, List<ListMember>>{};
    for (final row in await query.get()) {
      final membership = row.readTable(listMembers);
      final user = row.readTable(users);
      result
          .putIfAbsent(membership.listId, () => [])
          .add(
            ListMember(
              username: user.username,
              role: MemberRole.values.byName(membership.role),
            ),
          );
    }
    for (final members in result.values) {
      members.sort((a, b) {
        if (a.role != b.role) return a.role == MemberRole.owner ? -1 : 1;
        return a.username.compareTo(b.username);
      });
    }
    return result;
  }
}
