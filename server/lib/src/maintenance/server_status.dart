import 'dart:io';

import 'package:drift/drift.dart';
import 'package:nemo_server/src/db/server_database.dart';

/// What `nemo_server status` reports: how big the server has grown and
/// whether its housekeeping is being done.
///
/// For whoever hosts it, on the command line only. Nothing here is served
/// over HTTP: the counts say how many people use the server, which is
/// nobody else's business.
class ServerStatus {
  const ServerStatus({
    required this.databaseBytes,
    required this.accounts,
    required this.lists,
    required this.deletedLists,
    required this.tasks,
    required this.deletedTasks,
    required this.blobs,
    required this.blobBytes,
    required this.activeSessions,
    required this.lastHousekeeping,
  });

  /// The database file with its write-ahead log, which holds the recent
  /// writes until SQLite folds them in.
  final int databaseBytes;

  final int accounts;

  /// Live lists and tasks, not counting tombstones.
  final int lists;
  final int tasks;

  /// Tombstones still held, which a purge would eventually clear.
  final int deletedLists;
  final int deletedTasks;

  /// Photo files held, and their size, as the database records them.
  final int blobs;
  final int blobBytes;

  /// Sessions that have not expired.
  final int activeSessions;

  /// When `purge` last ran for real; null if it never has.
  final DateTime? lastHousekeeping;

  static Future<ServerStatus> read(
    ServerDatabase db, {
    required String dbPath,
    DateTime Function()? now,
  }) async {
    final at = (now ?? DateTime.now)();

    Future<int> count(
      TableInfo<Table, Object?> table, [
      Expression<bool>? where,
    ]) async {
      final rows = countAll();
      final query = db.selectOnly(table)..addColumns([rows]);
      if (where != null) query.where(where);
      final row = await query.getSingle();
      return row.read<int>(rows) ?? 0;
    }

    final blobBytes = db.blobs.byteSize.sum();
    final blobRow = await (db.selectOnly(
      db.blobs,
    )..addColumns([blobBytes])).getSingle();

    return ServerStatus(
      databaseBytes: _sizeOf(dbPath) + _sizeOf('$dbPath-wal'),
      accounts: await count(db.users),
      lists: await count(db.lists, db.lists.deletedAt.isNull()),
      deletedLists: await count(db.lists, db.lists.deletedAt.isNotNull()),
      tasks: await count(db.tasks, db.tasks.deletedAt.isNull()),
      deletedTasks: await count(db.tasks, db.tasks.deletedAt.isNotNull()),
      blobs: await count(db.blobs),
      blobBytes: blobRow.read<int>(blobBytes) ?? 0,
      activeSessions: await count(
        db.sessions,
        db.sessions.expiresAt.isBiggerThanValue(at.millisecondsSinceEpoch),
      ),
      lastHousekeeping: await db.lastHousekeeping(),
    );
  }

  static int _sizeOf(String path) {
    final file = File(path);
    return file.existsSync() ? file.lengthSync() : 0;
  }

  /// The report as `status` prints it, one fact to a line.
  String describe({required String dbPath, required DateTime now}) {
    final housekeeping = lastHousekeeping == null
        ? 'never -- see `nemo_server purge`'
        : 'last purge ${_ago(now.difference(lastHousekeeping!))} '
              '(${lastHousekeeping!.toUtc().toIso8601String()})';
    return [
      'database      $dbPath, ${formatBytes(databaseBytes)}',
      'accounts      $accounts',
      'lists         $lists ($deletedLists deleted, awaiting purge)',
      'tasks         $tasks ($deletedTasks deleted, awaiting purge)',
      'blobs         $blobs, ${formatBytes(blobBytes)}',
      'sessions      $activeSessions active',
      'housekeeping  $housekeeping',
    ].join('\n');
  }

  static String _ago(Duration d) {
    if (d.inDays >= 1) return '${d.inDays} day(s) ago';
    if (d.inHours >= 1) return '${d.inHours} hour(s) ago';
    return 'less than an hour ago';
  }
}

/// [bytes] in B, KB, MB or GB, whichever keeps the number readable.
String formatBytes(int bytes) {
  const units = ['KB', 'MB', 'GB'];
  if (bytes < 1024) return '$bytes B';
  var value = bytes / 1024;
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(1)} ${units[unit]}';
}
