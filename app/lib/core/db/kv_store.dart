import 'package:drift/drift.dart';
import 'package:nemo/core/db/app_database.dart';

abstract final class KvKeys {
  static const nodeId = 'node_id';
  static const hlcLast = 'hlc_last';
  static const cursor = 'sync_cursor';
  static const themeMode = 'theme_mode';
  static const serverUrl = 'server_url';
  static const username = 'username';
  static const lastSyncAt = 'last_sync_at';
  static const discarded = 'sync_discarded';
  static const lastUpdateCheck = 'last_update_check';
  static const dismissedUpdate = 'dismissed_update';
  static const trustedCertificates = 'trusted_certificates';
}

/// Typed access to the `kv` table.
class KvStore {
  KvStore(this._db);

  final AppDatabase _db;

  Future<String?> get(String key) async {
    final row = await (_db.select(
      _db.kv,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> set(String key, String? value) => _db
      .into(_db.kv)
      .insertOnConflictUpdate(
        KvCompanion.insert(key: key, value: Value(value)),
      );

  Stream<String?> watch(String key) => (_db.select(
    _db.kv,
  )..where((t) => t.key.equals(key))).watchSingleOrNull().map((r) => r?.value);
}
