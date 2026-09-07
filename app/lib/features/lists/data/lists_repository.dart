import 'package:drift/drift.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo_core/nemo_core.dart';

/// Lists: reads are streams over the local database, writes stamp an HLC
/// and queue the row for sync.
class ListsRepository {
  ListsRepository(this._db, this._clock, this._newId);

  final AppDatabase _db;
  final HlcClock _clock;
  final String Function() _newId;

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

  /// Tombstones the list; its tasks are hidden with it and stay restorable.
  Future<void> delete(String id) async {
    final list = await _db.listById(id);
    if (list == null || list.isInbox) return;
    final stamp = _clock.now().toString();
    await _db.upsertList(list.copyWith(updatedAt: stamp, deletedAt: stamp));
  }

  Future<void> restore(String id) async {
    final list = await _db.listById(id);
    if (list == null) return;
    await _db.upsertList(
      list.copyWith(updatedAt: _clock.now().toString(), deletedAt: null),
    );
  }
}
