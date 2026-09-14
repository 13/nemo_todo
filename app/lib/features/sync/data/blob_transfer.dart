import 'package:flutter/foundation.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/features/photos/data/photo_store.dart';
import 'package:nemo/features/sync/data/sync_client.dart';

/// What one pass of uploads came to.
///
/// `refusal` is the last refusal that asking again will not change -- too
/// large, or no room on the server -- and `retry` whether some other failure
/// may pass on a later try.
typedef UploadOutcome = ({bool landed, ApiError? refusal, bool retry});

/// Moves the bytes of pictures between this device and the server.
///
/// Rows travel through the sync; bytes travel here, beside it. Nothing in
/// this class touches sync state: it reports what happened and the engine
/// decides what that means for the run.
class BlobTransfer {
  BlobTransfer(this._db, this._store);

  final AppDatabase _db;
  final PhotoStore _store;

  /// How many blobs move at once. Two: enough to keep a home connection
  /// busy, few enough that a sync is not one long upload.
  static const concurrency = 2;

  /// Sends the bytes of every picture the server does not have yet.
  ///
  /// A blob that lands flips to `synced`, which is what releases its row
  /// into the push that follows: the server never holds a photo row it
  /// cannot serve the picture for. A failure is left queued and tried
  /// again.
  Future<UploadOutcome> uploadPending(SyncClient client) async {
    final pending = await _db.pendingBlobs();
    if (pending.isEmpty) return (landed: false, refusal: null, retry: false);
    var landed = false;
    final failures = await _forEachLimited(pending.map((b) => b.sha256), (
      sha256,
    ) async {
      final bytes = await _store.get(sha256);
      // The bytes are gone from this device -- a web tab that was reloaded
      // before the upload finished. The photo row stays held: pushing it
      // would name a picture nobody can fetch. Adding the same picture
      // again, or another device uploading it, is what can release it.
      if (bytes == null) return;
      await client.uploadBlob(sha256, bytes);
      await _db.markBlobSynced(sha256);
      landed = true;
      // Only now does a second copy exist, so only now may the web store
      // evict these bytes like any others.
      await _store.unpin(sha256);
    });
    return (
      landed: landed,
      refusal: failures
          .where((e) => e.status == 413 || e.status == 507)
          .lastOrNull,
      retry: _retryable(failures),
    );
  }

  /// Fetches the bytes of pictures that arrived as rows, newest first.
  /// Answers whether a failure may pass on a later try.
  Future<bool> downloadMissing(SyncClient client) async {
    final missing = await _db.missingBlobHashes();
    final failures = await _forEachLimited(missing, (sha256) async {
      final bytes = await client.downloadBlob(sha256);
      await _store.put(sha256, bytes);
      await _db.rememberBlob(sha256, byteSize: bytes.length, state: 'synced');
    });
    return _retryable(failures);
  }

  /// Marks every picture this device still holds as waiting for upload,
  /// for an account that has none of them.
  ///
  /// Only bytes this device still holds: a blob marked pending whose bytes
  /// are gone can never be uploaded, and would hold its row back forever.
  /// Left `synced`, the row still reaches the new account, which simply has
  /// no picture for it.
  Future<void> repend() async {
    final held = [
      for (final sha256 in await _db.syncedBlobHashes())
        if (await _store.get(sha256) != null) sha256,
    ];
    await _db.resetBlobsToPending(held);
    for (final sha256 in held) {
      // Their only copy on the new server is the upload to come.
      await _store.pin(sha256);
    }
  }

  /// Whether the server failed a transfer in a way that may pass. Not 404
  /// -- a server too old to have blob routes, which would be polled forever
  /// -- nor 413 or 507, which asking again will not change. A failure on
  /// this device never reaches here: it is logged instead.
  static bool _retryable(List<ApiError> failures) =>
      failures.any((e) => !const {404, 413, 507}.contains(e.status));

  /// Runs [action] over [items], [concurrency] at a time, in order.
  /// Returns the refusals the server answered with.
  ///
  /// One item failing does not stop the rest, nor the sync: pictures are
  /// independent, and the next sync tries whatever is still missing.
  static Future<List<ApiError>> _forEachLimited(
    Iterable<String> items,
    Future<void> Function(String) action,
  ) async {
    final queue = items.toList();
    final refusals = <ApiError>[];
    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final item = queue.removeAt(0);
        try {
          await action(item);
        } on ApiError catch (e) {
          refusals.add(e);
        } on Object catch (e, stack) {
          // Something on this device -- a full disk under the store, the
          // database refusing a write -- is worth a line in the log, not
          // failing the tasks' sync over one picture. So is the
          // ArgumentError `FilePhotoStore.put` documents for a hash that is
          // not a digest, which a corrupted row can carry: left to escape,
          // it would fail every sync from then on. Any other Error is a bug
          // and stays loud.
          if (e is! Exception && e is! ArgumentError) rethrow;
          debugPrint('picture $item not moved: $e\n$stack');
        }
      }
    }

    await Future.wait([for (var i = 0; i < concurrency; i++) worker()]);
    return refusals;
  }
}
