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
  int get schemaVersion => 1;
}
