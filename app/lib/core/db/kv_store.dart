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
  static const serverVersion = 'server_version';

  /// The server and account (`"$serverUrl|$username"`) that last received
  /// this device's picture bytes.
  static const blobAccount = 'blob_account';

  /// `"true"` once the server's last answer said it takes photo changes.
  /// Unset or anything else means it has not, and photo changes stay queued.
  static const serverPhotos = 'server_photos';

  /// `"true"` once the server's last answer said it takes note changes.
  /// Unset or anything else means it has not, and note changes -- and the
  /// pictures hanging on a note -- stay queued.
  static const serverNotes = 'server_notes';

  /// JSON list of achievement ids this device has already celebrated, or
  /// quietly recorded as reached. Unset until the first check.
  static const achievementsSeen = 'achievements_seen';

  /// How many days this device saw Today cleared, and the last such day as
  /// `yyyy-mm-dd`, so one day is counted once.
  static const clearedDays = 'cleared_days';
  static const lastClearedDay = 'last_cleared_day';

  /// Per-device celebration switches: `"true"` or `"false"`; unset is the
  /// default (celebrations and achievements on, sound off).
  static const celebrations = 'celebrations';
  static const celebrationSound = 'celebration_sound';
  static const achievements = 'achievements';
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
