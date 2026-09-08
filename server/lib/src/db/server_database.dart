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

  @override
  int get schemaVersion => 2;

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
    },
  );
}
