import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:nemo_core/nemo_core.dart';
import 'package:nemo_server/src/db/server_tables.dart';
import 'package:nemo_server/src/db/sync_tables.dart';

part 'server_database.g.dart';

/// The server's single SQLite database: the synced tables shared with the
/// app plus accounts, sessions, memberships and the change log.
@DriftDatabase(
  tables: [Lists, Tasks, Subtasks, Users, Sessions, ListMembers, SyncLog],
)
class ServerDatabase extends _$ServerDatabase {
  ServerDatabase(super.e);

  ServerDatabase.memory() : super(NativeDatabase.memory());

  ServerDatabase.file(String path)
    : super(
        NativeDatabase.createInBackground(
          File(path),
          setup: (db) {
            db
              ..execute('pragma journal_mode = wal')
              ..execute('pragma foreign_keys = on')
              ..execute('pragma busy_timeout = 5000');
          },
        ),
      );

  /// Writes a consistent copy of the database to [path], with the server
  /// still running.
  ///
  /// Copying the file by hand is not the same thing: with WAL on, the
  /// recent writes live in a second file, and a copy taken mid-write can
  /// be torn. `vacuum into` takes its own read transaction and writes a
  /// single tidy file, and it refuses to overwrite, so a backup can never
  /// quietly land on top of another one.
  Future<void> backupTo(String path) =>
      customStatement('vacuum into ?', [path]);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // Indexes are created one by one rather than with createAll(): drift
      // emits index DDL without `if not exists`, so createAll() throws on a
      // database that already holds the tables.
      if (from < 2) {
        await m.create(listMembersUserId);
        await m.create(syncLogRow);
      }
      // Version 3 carries how often a task comes back. The server never
      // reads it; it stores and forwards it like every other column.
      if (from < 3) await m.addColumn(tasks, tasks.repeat);
    },
  );
}
