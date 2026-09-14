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
  tables: [Lists, Tasks, Subtasks, Photos, Outbox, ListMeta, Kv, Blobs],
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
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // Version 2 carries how often a task comes back. Null on every row
      // that existed before, which is what "happens once" already meant.
      if (from < 2) await m.addColumn(tasks, tasks.repeat);
      // Version 3 carries pictures: the rows, and what this device holds
      // the bytes for.
      if (from < 3) {
        await m.createTable(photos);
        await m.create(photosTaskId);
        await m.createTable(blobs);
        // While this device ran a build without photos, the server skipped
        // photo changes for it and moved its cursor past them. Starting the
        // change log over -- the path every first sync takes -- is what
        // brings those pictures back; rows it already holds merge as no-ops.
        await (delete(kv)..where((t) => t.key.equals(KvKeys.cursor))).go();
      }
    },
    beforeOpen: (details) async {
      await customStatement('pragma foreign_keys = on');
    },
  );
}
