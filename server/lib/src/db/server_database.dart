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
  tables: [
    Lists,
    Tasks,
    Subtasks,
    Photos,
    Users,
    Sessions,
    ListMembers,
    SyncLog,
    Blobs,
  ],
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
  int get schemaVersion => 5;

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
      // Version 4 carries pictures: the rows that name them, and the
      // bytes the server is holding for them.
      //
      // `m.createTable`/`m.create` build from the table's *current* Dart
      // definition, not a snapshot of what version 4 looked like. A device
      // jumping here from before photos existed gets the photos table in
      // its final (version 5) shape directly -- parent_id and parent_kind
      // already, no task_id -- so the version-5 block below has nothing
      // left to do for it.
      if (from < 4) {
        await m.createTable(photos);
        await m.create(photosParent);
        await m.createTable(blobs);
      }
      // Version 5 lets a picture hang on a note as well as a task. Only a
      // device that already has a version-4 photos table -- built on the
      // old schema, with task_id -- needs this: the block above already
      // gave a fresher device the final shape.
      if (from < 5 && from >= 4) {
        // The backfill runs while task_id is still there: dropping it first
        // would leave every picture without a parent, and there is no
        // second place to recover one from.
        //
        // parent_id is added by hand, nullable: sqlite refuses to add a NOT
        // NULL column without a default, and the Dart column has none --
        // every row gets a value from the backfill below before the rebuild
        // that gives it its real, non-null definition.
        await customStatement('alter table photos add column parent_id text');
        await m.addColumn(photos, photos.parentKind);
        await customStatement(
          "update photos set parent_id = task_id, parent_kind = 'task'",
        );
        await customStatement("delete from photos where parent_id = ''");
        // Dropped before `alterTable`: that call re-creates whatever
        // indexes it finds on the table it is rebuilding, and the old
        // index's SQL names task_id, a column the rebuilt table will not
        // have any more.
        await customStatement('drop index if exists photos_task_id');
        await m.alterTable(TableMigration(photos));
        await m.createIndex(photosParent);
      }
    },
  );
}
