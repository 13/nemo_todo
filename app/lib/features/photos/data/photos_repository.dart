import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/features/photos/data/photo_pipeline.dart';
import 'package:nemo/features/photos/data/photo_store.dart';
import 'package:nemo_core/nemo_core.dart';

/// The pictures on a task or a note: adding one, removing one, and finding
/// its bytes.
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

  Stream<List<Photo>> watchByParent(PhotoParent kind, String id) =>
      (_db.select(_db.photos)
            ..where(
              (t) =>
                  t.parentKind.equalsValue(kind) &
                  t.parentId.equals(id) &
                  t.deletedAt.isNull(),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.sortKey)]))
          .watch();

  /// How many live pictures each task has, for the list tiles. Note photos
  /// are not counted here: this feeds the task list tiles alone.
  Stream<Map<String, int>> watchCounts() =>
      (_db.select(_db.photos)..where(
            (t) =>
                t.deletedAt.isNull() &
                t.parentKind.equalsValue(PhotoParent.task),
          ))
          .watch()
          .map((rows) {
            final counts = <String, int>{};
            for (final row in rows) {
              counts[row.parentId] = (counts[row.parentId] ?? 0) + 1;
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
  Future<Photo?> add(PhotoParent kind, String parentId, Uint8List raw) async {
    final processed = await _process(raw);
    if (processed == null) return null;
    final last =
        await (_db.select(_db.photos)
              ..where(
                (t) =>
                    t.parentKind.equalsValue(kind) &
                    t.parentId.equals(parentId) &
                    t.deletedAt.isNull(),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.sortKey)])
              ..limit(1))
            .getSingleOrNull();
    final photo = Photo(
      id: _newId(),
      parentKind: kind,
      parentId: parentId,
      sha256: processed.sha256,
      byteSize: processed.bytes.length,
      width: processed.width,
      height: processed.height,
      sortKey: last == null ? SortKey.first() : SortKey.after(last.sortKey),
      updatedAt: _clock.now().toString(),
    );
    await _store.put(processed.sha256, processed.bytes);
    // Bytes with no other copy yet -- a picture added on the web, still on
    // its way to the server -- must not be evicted before the upload that
    // is their only other copy has finished with them. The sync engine
    // unpins once that upload succeeds.
    await _store.pin(processed.sha256);
    // Uploaded again even when this device already recorded these bytes as
    // `synced`: that is only what the server said last time, and it may
    // have swept them since. A row reaching it without its bytes is a
    // broken picture on every other device, while a redundant upload costs
    // one request the server dedupes -- and refreshes the age it sweeps by.
    //
    // The blob is recorded before the row, so the row can never be found
    // pushable before the bytes it needs are known about.
    await _db.rememberBlob(
      processed.sha256,
      byteSize: processed.bytes.length,
      state: 'pendingUpload',
    );
    await _db.upsertPhoto(photo);
    return photo;
  }

  Future<void> delete(String id) async {
    final photo = await _db.photoById(id);
    if (photo == null) return;
    final stamp = _clock.now().toString();
    await _db.upsertPhoto(photo.copyWith(updatedAt: stamp, deletedAt: stamp));
    // The same picture may hang off another task or note -- the hash is the
    // bytes, not the attachment -- so the bytes only go when nothing names
    // them.
    if (await _db.forgetUnusedBlob(photo.sha256)) {
      await _store.remove(photo.sha256);
    }
  }
}
