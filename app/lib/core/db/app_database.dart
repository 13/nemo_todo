import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:nemo/core/db/app_tables.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/db/sync_tables.dart';
import 'package:nemo_core/nemo_core.dart';

part 'app_database.g.dart';

/// The app's local database: the synced tables plus outbox, sharing
/// metadata and a key-value store.
@DriftDatabase(
  tables: [Lists, Tasks, Subtasks, Photos, Notes, Outbox, ListMeta, Kv, Blobs],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Opens the on-device database (SQLite file on Android, sqlite3 in
  /// WebAssembly backed by IndexedDB/OPFS on the web).
  factory AppDatabase.open() => AppDatabase(
    driftDatabase(
      name: 'nemo',
      web: DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    ),
  );

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // Version 2 carries how often a task comes back. Null on every row
      // that existed before, which is what "happens once" already meant.
      if (from < 2) await m.addColumn(tasks, tasks.repeat);
      // Version 3 carries pictures: the rows, and what this device holds
      // the bytes for.
      //
      // `m.createTable`/`m.create` build from the table's *current* Dart
      // definition, not a snapshot of what version 3 looked like. A device
      // jumping here from before photos existed gets the photos table in
      // its final (version 4) shape directly -- parent_id and parent_kind
      // already, no task_id -- so the version-4 block below has nothing
      // left to do for it.
      if (from < 3) {
        await m.createTable(photos);
        await m.create(photosParent);
        await m.createTable(blobs);
        // While this device ran a build without photos, the server skipped
        // photo changes for it and moved its cursor past them. Starting the
        // change log over -- the path every first sync takes -- is what
        // brings those pictures back; rows it already holds merge as no-ops.
        await (delete(kv)..where((t) => t.key.equals(KvKeys.cursor))).go();
      }
      // Version 4 also adds the notes table. Notes are brand new at this
      // version -- there is no earlier shape of them to have -- so unlike
      // the photo parent columns below, creating this table does not
      // depend on which version the device is coming from: every device
      // below 4 needs it exactly once, whether it jumped here from before
      // photos existed or is stepping up from a version-3 install.
      if (from < 4) {
        await m.createTable(notes);
        await m.createIndex(notesListId);
      }
      // The photo parent columns, on the other hand, are only missing on a
      // device that already has a version-3 photos table -- built on the
      // old schema, with task_id -- so this block is guarded to a device
      // coming from exactly that version: the block above already gave a
      // fresher device (jumping in below version 3) the final shape.
      if (from < 4 && from >= 3) {
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
    beforeOpen: (details) async {
      await customStatement('pragma foreign_keys = on');
    },
  );
}
