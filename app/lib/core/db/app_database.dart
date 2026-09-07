import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:nemo/core/db/app_tables.dart';
import 'package:nemo/core/db/sync_tables.dart';
import 'package:nemo_core/nemo_core.dart';

part 'app_database.g.dart';

/// The app's local database: the synced tables plus outbox, sharing
/// metadata and a key-value store.
@DriftDatabase(tables: [Lists, Tasks, Subtasks, Outbox, ListMeta, Kv])
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
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    beforeOpen: (details) async {
      await customStatement('pragma foreign_keys = on');
    },
  );
}
