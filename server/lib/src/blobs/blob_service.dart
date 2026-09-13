import 'package:drift/drift.dart';
import 'package:nemo_server/src/api_exception.dart';
import 'package:nemo_server/src/blobs/blob_store.dart';
import 'package:nemo_server/src/db/server_database.dart';
import 'package:nemo_server/src/sync/sync_log_writer.dart';

/// Accepting and handing back the bytes of pictures.
///
/// A blob is immutable and named by its content, so there is no merge, no
/// conflict and no version: the only questions are whether the bytes are
/// what they claim to be, whether this account may store them, and whether
/// this account may read them.
class BlobService {
  BlobService(
    this._db,
    this._store, {
    required this.maxBlobBytes,
    required this.accountQuotaBytes,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final ServerDatabase _db;
  final BlobStore _store;
  final DateTime Function() _now;
  final int maxBlobBytes;
  final int accountQuotaBytes;

  Future<void> put(String userId, String sha256, List<int> bytes) async {
    // Checked before anything touches the database or the filesystem: a
    // hash this shape is not content-addressing, it is a path a caller is
    // trying to choose for `BlobStore.fileFor`. Note it is compared as
    // given, never lowercased - the stored row and path must equal exactly
    // what photo rows carry, or `canSeeBlob` and `fileFor` would disagree
    // with what got written here.
    if (!BlobStore.isValidHash(sha256)) {
      throw const ApiException(400, 'invalid_hash');
    }
    if (bytes.length > maxBlobBytes) {
      throw const ApiException(413, 'blob_too_large');
    }
    if (BlobStore.hashOf(bytes) != sha256) {
      throw const ApiException(400, 'hash_mismatch');
    }
    // Already held: it costs the caller nothing whether they were the one
    // who paid for it or not, and no bytes are written. But the upload is
    // almost always followed by a push of the row that names it, so the
    // blob is made young again: an old orphan re-uploaded must not be swept
    // between the two. That is a write rather than a read on purpose - it
    // takes the database's write lock, so it waits out a purge (another
    // process) in the middle of claiming this blob, and then either finds
    // the row still there and refreshes it, or finds it gone and stores
    // the bytes afresh below.
    final held =
        await (_db.update(
          _db.blobs,
        )..where((t) => t.sha256.equals(sha256))).write(
          BlobsCompanion(createdAt: Value(_now().millisecondsSinceEpoch)),
        );
    if (held > 0) {
      if (!await _store.exists(sha256)) await _store.write(sha256, bytes);
      return;
    }
    final owned = await _db.bytesOwnedBy(userId);
    if (owned + bytes.length > accountQuotaBytes) {
      throw const ApiException(507, 'quota_exceeded');
    }
    // The file first: a row naming bytes that are not there would be a
    // download that 404s, while a file no row names is swept later.
    await _store.write(sha256, bytes);
    await _db
        .into(_db.blobs)
        .insert(
          BlobsCompanion.insert(
            sha256: sha256,
            byteSize: bytes.length,
            ownerUserId: userId,
            createdAt: _now().millisecondsSinceEpoch,
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  /// The bytes, or a 404 - which is also the answer for bytes that exist
  /// but are attached to nothing this account can see, and for a hash that
  /// could never name a blob at all. Saying anything more specific for a
  /// malformed hash would tell a prober its shape was the problem, not the
  /// content; saying "forbidden" for a real one would confirm the picture
  /// exists.
  Future<Stream<List<int>>> get(String userId, String sha256) async {
    if (!BlobStore.isValidHash(sha256)) {
      throw const ApiException(404, 'not_found');
    }
    if (!await _db.canSeeBlob(userId, sha256)) {
      throw const ApiException(404, 'not_found');
    }
    if (!await _store.exists(sha256)) {
      throw const ApiException(404, 'not_found');
    }
    return _store.read(sha256);
  }
}
