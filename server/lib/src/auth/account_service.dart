import 'package:drift/drift.dart';
import 'package:nemo_core/nemo_core.dart';
import 'package:nemo_server/src/db/server_database.dart';
import 'package:nemo_server/src/sync/sync_log_writer.dart';

/// Removing an account and everything only it could see.
class AccountService {
  AccountService(this._db);

  final ServerDatabase _db;

  /// Deletes [userId], its sessions, and the lists nobody else is on.
  /// Returns the user ids whose lists changed, to notify.
  ///
  /// A list shared with others is not the leaving account's to take with
  /// it: it goes to the member first by username, the same way the members
  /// screen lists them, so what the others were working on stays put and
  /// still has someone who can administer it. A list the account was only
  /// a member of simply loses that member.
  ///
  /// Rows are deleted outright rather than tombstoned: no device of this
  /// account can sync again to hear about a tombstone. Picture bytes no
  /// longer named by any photo are left for the purge to sweep, which is
  /// what it already does for every other photo that goes away.
  Future<Set<String>> delete(String userId) {
    return _db.transaction(() async {
      final notify = <String>{};
      final roles = await _db.rolesOf(userId);
      for (final MapEntry(key: listId, value: role) in roles.entries) {
        final remaining = await _remainingMembers(listId, userId);
        if (role == MemberRole.owner && remaining.isEmpty) {
          await _deleteList(listId);
          continue;
        }
        if (role == MemberRole.owner) {
          await _handOver(listId, remaining.first);
        }
        await (_db.delete(_db.listMembers)
              ..where((t) => t.listId.equals(listId) & t.userId.equals(userId)))
            .go();
        notify.addAll(remaining.map((u) => u.id));
      }
      await (_db.delete(
        _db.syncLog,
      )..where((t) => t.forUserId.equals(userId))).go();
      await (_db.delete(
        _db.sessions,
      )..where((t) => t.userId.equals(userId))).go();
      await (_db.delete(_db.users)..where((t) => t.id.equals(userId))).go();
      return notify;
    });
  }

  /// Everyone on [listId] but [userId], by username.
  Future<List<User>> _remainingMembers(String listId, String userId) async {
    final query =
        _db.select(_db.users).join([
            innerJoin(
              _db.listMembers,
              _db.listMembers.userId.equalsExp(_db.users.id),
            ),
          ])
          ..where(
            _db.listMembers.listId.equals(listId) &
                _db.users.id.equals(userId).not(),
          )
          ..orderBy([OrderingTerm.asc(_db.users.username)]);
    return [for (final row in await query.get()) row.readTable(_db.users)];
  }

  Future<void> _handOver(String listId, User successor) async {
    await (_db.update(_db.listMembers)..where(
          (t) => t.listId.equals(listId) & t.userId.equals(successor.id),
        ))
        .write(ListMembersCompanion(role: Value(MemberRole.owner.name)));
    // Clients read the owner off the row itself, so it travels again.
    await (_db.update(_db.lists)..where((t) => t.id.equals(listId))).write(
      ListsCompanion(ownerId: Value(successor.id)),
    );
    await _db.logUpsert(SyncEntity.list, listId, listId);
    // Notes need no statement here: they are keyed by listId exactly as
    // tasks are, so a list handed over already carries them, and nothing
    // in the sync log names their old owner.
  }

  Future<void> _deleteList(String listId) async {
    final taskIds = [for (final t in await _db.tasksOfList(listId)) t.id];
    if (taskIds.isNotEmpty) {
      await (_db.delete(
        _db.subtasks,
      )..where((t) => t.taskId.isIn(taskIds))).go();
      await (_db.delete(_db.photos)..where(
            (t) =>
                t.parentKind.equalsValue(PhotoParent.task) &
                t.parentId.isIn(taskIds),
          ))
          .go();
      await (_db.delete(_db.tasks)..where((t) => t.id.isIn(taskIds))).go();
    }
    // Notes are not gated behind `taskIds.isNotEmpty` above: a list can
    // hold notes and no tasks at all, and a note left behind here would
    // hold its blobs alive forever -- nothing else ever purges a photo
    // whose list no longer exists to look it up through.
    final noteIds = [for (final n in await _db.notesOfList(listId)) n.id];
    if (noteIds.isNotEmpty) {
      await (_db.delete(_db.photos)..where(
            (t) =>
                t.parentKind.equalsValue(PhotoParent.note) &
                t.parentId.isIn(noteIds),
          ))
          .go();
      await (_db.delete(_db.notes)..where((t) => t.id.isIn(noteIds))).go();
    }
    await (_db.delete(_db.lists)..where((t) => t.id.equals(listId))).go();
    await (_db.delete(
      _db.listMembers,
    )..where((t) => t.listId.equals(listId))).go();
    await (_db.delete(_db.syncLog)..where((t) => t.listId.equals(listId))).go();
  }
}
