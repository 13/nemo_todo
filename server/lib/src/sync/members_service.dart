import 'package:drift/drift.dart';
import 'package:nemo_core/nemo_core.dart';
import 'package:nemo_server/src/api_exception.dart';
import 'package:nemo_server/src/db/server_database.dart';
import 'package:nemo_server/src/sync/sync_log_writer.dart';

/// Sharing lists with other accounts.
class MembersService {
  MembersService(this._db);

  final ServerDatabase _db;

  Future<List<ListMember>> members(String userId, String listId) async {
    final roles = await _db.rolesOf(userId);
    if (!roles.containsKey(listId)) {
      throw const ApiException(404, 'unknown_list');
    }
    return (await _db.membersOf([listId]))[listId] ?? const [];
  }

  /// Adds [username] as editor. Returns the user ids to notify.
  Future<Set<String>> share(
    String ownerId,
    String listId,
    String username,
    MemberRole role,
  ) {
    return _db.transaction(() async {
      if (role == MemberRole.owner) {
        throw const ApiException(400, 'cannot_change_owner');
      }
      await _requireOwner(ownerId, listId);
      final target = await _userByName(username);
      final current = await _membership(listId, target.id);
      if (current?.role == MemberRole.owner.name) {
        throw const ApiException(400, 'cannot_change_owner');
      }
      await _db
          .into(_db.listMembers)
          .insertOnConflictUpdate(
            ListMembersCompanion.insert(
              listId: listId,
              userId: target.id,
              role: role.name,
            ),
          );
      await _relogList(listId);
      return await _db.memberUserIds(listId);
    });
  }

  /// Removes [username]. Returns the user ids to notify (removed one too).
  Future<Set<String>> unshare(String ownerId, String listId, String username) {
    return _db.transaction(() async {
      await _requireOwner(ownerId, listId);
      final target = await _userByName(username);
      final membership = await _membership(listId, target.id);
      if (membership == null) throw const ApiException(404, 'not_member');
      if (membership.role == MemberRole.owner.name) {
        throw const ApiException(400, 'cannot_remove_owner');
      }
      await (_db.delete(
            _db.listMembers,
          )..where((t) => t.listId.equals(listId) & t.userId.equals(target.id)))
          .go();
      await _db.logRevoke(
        SyncEntity.list,
        listId,
        listId: listId,
        forUserId: target.id,
      );
      for (final task in await _db.tasksOfList(listId)) {
        await _db.logRevoke(
          SyncEntity.task,
          task.id,
          listId: listId,
          forUserId: target.id,
        );
        for (final sub in await _db.subtasksOfTask(task.id)) {
          await _db.logRevoke(
            SyncEntity.subtask,
            sub.id,
            listId: listId,
            forUserId: target.id,
          );
        }
      }
      return {...await _db.memberUserIds(listId), target.id};
    });
  }

  Future<void> _requireOwner(String userId, String listId) async {
    final role = (await _db.rolesOf(userId))[listId];
    if (role == null) throw const ApiException(404, 'unknown_list');
    if (role != MemberRole.owner) throw const ApiException(403, 'not_owner');
  }

  Future<User> _userByName(String username) async {
    final user =
        await (_db.select(_db.users)
              ..where((t) => t.username.equals(username.trim().toLowerCase())))
            .getSingleOrNull();
    if (user == null) throw const ApiException(404, 'unknown_user');
    return user;
  }

  Future<ListMemberRow?> _membership(String listId, String userId) =>
      (_db.select(_db.listMembers)
            ..where((t) => t.listId.equals(listId) & t.userId.equals(userId)))
          .getSingleOrNull();

  /// Bumps every row of the list so a new member receives all of it.
  Future<void> _relogList(String listId) async {
    await _db.logUpsert(SyncEntity.list, listId, listId);
    for (final task in await _db.tasksOfList(listId)) {
      await _db.logUpsert(SyncEntity.task, task.id, listId);
      for (final sub in await _db.subtasksOfTask(task.id)) {
        await _db.logUpsert(SyncEntity.subtask, sub.id, listId);
      }
    }
  }
}
