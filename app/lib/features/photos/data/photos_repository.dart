import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/features/photos/data/photo_pipeline.dart';
import 'package:nemo/features/photos/data/photo_store.dart';
import 'package:nemo_core/nemo_core.dart';

/// The pictures on a task: adding one, removing one, and finding its bytes.
class PhotosRepository {
  PhotosRepository(
    this._db,
    this._clock,
    this._newId,
    this._store, {
    Future<ProcessedPhoto?> Function(Uint8List raw)? process,
  }) : _process = process ?? ((raw) => compute(processPhoto, raw));

  final AppDatabase _db;
  final HlcClock _clock;
  final String Function() _newId;
  final PhotoStore _store;

  // Off the UI isolate in the app: decoding, baking orientation, resizing
  // and re-encoding a 12 MP photo can take seconds, and this runs from
  // "take photo", not from a background job. Injectable because a real
  // isolate never reports back to a widget test's fake clock, so those
  // tests supply a synchronous stand-in instead.
  final Future<ProcessedPhoto?> Function(Uint8List raw) _process;

  Stream<List<Photo>> watchByTask(String taskId) =>
      (_db.select(_db.photos)
            ..where((t) => t.taskId.equals(taskId) & t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.asc(t.sortKey)]))
          .watch();

  /// How many live pictures each task has, for the list tiles.
  Stream<Map<String, int>> watchCounts() =>
      (_db.select(_db.photos)..where((t) => t.deletedAt.isNull())).watch().map((
        rows,
      ) {
        final counts = <String, int>{};
        for (final row in rows) {
          counts[row.taskId] = (counts[row.taskId] ?? 0) + 1;
        }
        return counts;
      });

  Future<Uint8List?> bytes(String sha256) => _store.get(sha256);

  /// Hashes whose bytes the server does not have yet, so a picture can
  /// say so rather than looking like every other one.
  Stream<Set<String>> watchPendingHashes() =>
      (_db.select(_db.blobs)..where((t) => t.state.equals('pendingUpload')))
          .watch()
          .map((rows) => {for (final row in rows) row.sha256});

  /// Processes [raw], stores the bytes and queues the row. Returns null
  /// for bytes that are not a picture, writing nothing in that case.
  Future<Photo?> add(String taskId, Uint8List raw) async {
    final processed = await _process(raw);
    if (processed == null) return null;
    final last =
        await (_db.select(_db.photos)
              ..where((t) => t.taskId.equals(taskId) & t.deletedAt.isNull())
              ..orderBy([(t) => OrderingTerm.desc(t.sortKey)])
              ..limit(1))
            .getSingleOrNull();
    final photo = Photo(
      id: _newId(),
      taskId: taskId,
      sha256: processed.sha256,
      byteSize: processed.bytes.length,
      width: processed.width,
      height: processed.height,
      sortKey: last == null ? SortKey.first() : SortKey.after(last.sortKey),
      updatedAt: _clock.now().toString(),
    );
    // This device may already hold these exact bytes -- another photo, or
    // the same one added twice -- and if the server already has them too,
    // recording `pendingUpload` unconditionally would flip a `synced` blob
    // back, re-upload it, and hold this row behind that upload for no
    // reason. So the existing state decides, not a blanket overwrite.
    final alreadySynced = await _blobState(processed.sha256) == 'synced';
    await _store.put(processed.sha256, processed.bytes);
    if (!alreadySynced) {
      // Bytes with no other copy yet -- a picture added on the web, still
      // on its way to the server -- must not be evicted before the upload
      // that is their only other copy has finished with them. The sync
      // engine unpins once that upload succeeds.
      await _store.pin(processed.sha256);
      // The blob is recorded before the row, so the row can never be found
      // pushable before the bytes it needs are known about.
      await _db.rememberBlob(
        processed.sha256,
        byteSize: processed.bytes.length,
        state: 'pendingUpload',
      );
    }
    await _db.upsertPhoto(photo);
    return photo;
  }

  Future<void> delete(String id) async {
    final photo = await _db.photoById(id);
    if (photo == null) return;
    final stamp = _clock.now().toString();
    await _db.upsertPhoto(photo.copyWith(updatedAt: stamp, deletedAt: stamp));
    // The same picture may hang off another task -- the hash is the bytes,
    // not the attachment -- so the bytes only go when nothing names them.
    if (await _db.forgetUnusedBlob(photo.sha256)) {
      await _store.remove(photo.sha256);
    }
  }

  /// The recorded state of a blob, or null if this device has no row for
  /// it. There is no existing reader for a single blob by hash, so this
  /// stays a small private query rather than growing `SyncWrites`.
  Future<String?> _blobState(String sha256) async => (await (_db.select(
    _db.blobs,
  )..where((t) => t.sha256.equals(sha256))).getSingleOrNull())?.state;
}
