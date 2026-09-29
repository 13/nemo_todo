import 'package:drift/drift.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo_core/nemo_core.dart';

/// Which picture bytes this device holds, and which the server has.
extension SyncBlobs on AppDatabase {
  /// Records that this device holds bytes for [sha256].
  Future<void> rememberBlob(
    String sha256, {
    required int byteSize,
    required String state,
  }) => into(blobs).insertOnConflictUpdate(
    BlobsCompanion.insert(sha256: sha256, byteSize: byteSize, state: state),
  );

  Future<void> markBlobSynced(String sha256) =>
      (update(blobs)..where((t) => t.sha256.equals(sha256))).write(
        const BlobsCompanion(state: Value('synced')),
      );

  /// Hashes of the blobs the server this device last talked to has.
  Future<List<String>> syncedBlobHashes() async => [
    for (final r in await (select(
      blobs,
    )..where((t) => t.state.equals('synced'))).get())
      r.sha256,
  ];

  /// Marks the blobs named by [hashes] as waiting for an upload again.
  /// `synced` only ever meant "the server this device last talked to has
  /// them", which says nothing about a different one.
  Future<void> resetBlobsToPending(Iterable<String> hashes) {
    final list = hashes.toList();
    if (list.isEmpty) return Future.value();
    return (update(blobs)..where((t) => t.sha256.isIn(list))).write(
      const BlobsCompanion(state: Value('pendingUpload')),
    );
  }

  /// Blobs waiting to be uploaded.
  ///
  /// A blob whose only live pictures hang on a note is left out until the
  /// server is *known* to take notes -- not only once it has explicitly
  /// said it does not. Unset means exactly the same "not yet known" that a
  /// literal `'false'` does: the notes gate on the row itself already
  /// treats them alike, and the blob endpoints have no notes gate of their
  /// own to 404 the mistake the way a photos-blind server does, so an
  /// upload offered on the strength of an unset flag would simply succeed,
  /// stranding bytes behind a row the server will never take. That picture's
  /// row is held back the same way a note's own row is, so offering its
  /// bytes anyway would let a rolled-back (or not-yet-caught-up) server's
  /// blob sweep delete them before the row that names them ever lands. A
  /// blob a task also names, or one the server is known to take notes for,
  /// is never held here.
  Future<List<BlobRow>> pendingBlobs() async {
    final pending = await (select(
      blobs,
    )..where((t) => t.state.equals('pendingUpload'))).get();
    if (pending.isEmpty) return pending;
    final notesFlag = await (select(
      kv,
    )..where((t) => t.key.equals(KvKeys.serverNotes))).getSingleOrNull();
    if (notesFlag?.value == 'true') return pending;
    final noteOnly = await _noteOnlyBlobShas(pending);
    if (noteOnly.isEmpty) return pending;
    return [
      for (final blob in pending)
        if (!noteOnly.contains(blob.sha256)) blob,
    ];
  }

  /// Whether some pending blob is held only because every live picture
  /// naming it hangs on a note -- regardless of what is currently known
  /// about the server's note support. Lets the engine notice, on the round
  /// a notes-blind server turns out to take them after all, that bytes
  /// [pendingBlobs] was withholding this round are worth another round --
  /// without mistaking some unrelated stuck blob (a task picture that
  /// failed to upload) for one of these, which would send the engine round
  /// after round for a reason that has nothing to do with notes.
  Future<bool> hasHeldNoteBlobs() async {
    final pending = await (select(
      blobs,
    )..where((t) => t.state.equals('pendingUpload'))).get();
    if (pending.isEmpty) return false;
    return (await _noteOnlyBlobShas(pending)).isNotEmpty;
  }

  /// The hashes among [pending] whose every live photo row hangs on a
  /// note. One query for every pending blob, not one per blob: fetch every
  /// live photo naming one of them and group by hash locally.
  Future<Set<String>> _noteOnlyBlobShas(List<BlobRow> pending) async {
    final shas = [for (final blob in pending) blob.sha256];
    final rows = await (select(
      photos,
    )..where((t) => t.sha256.isIn(shas) & t.deletedAt.isNull())).get();
    final byHash = <String, List<Photo>>{};
    for (final row in rows) {
      (byHash[row.sha256] ??= []).add(row);
    }
    return {
      for (final blob in pending)
        if (byHash[blob.sha256] case final rows?
            when rows.isNotEmpty &&
                rows.every((p) => p.parentKind == PhotoParent.note))
          blob.sha256,
    };
  }

  /// Hashes named by a live photo row that this device does not hold,
  /// those of the most recently changed photos first: the picture someone
  /// just attached is the one they are about to look for. `updated_at` is
  /// an HLC string, which sorts in the order the changes happened.
  Future<List<String>> missingBlobHashes() async {
    final rows = await customSelect(
      'select p.sha256 as sha256 from photos p '
      'where p.deleted_at is null '
      'and p.sha256 not in (select sha256 from blobs) '
      'group by p.sha256 '
      'order by max(p.updated_at) desc',
      readsFrom: {photos, blobs},
    ).get();
    return [for (final r in rows) r.read<String>('sha256')];
  }

  /// Forgets a blob once no live photo row names it. Returns whether it
  /// was forgotten, so the caller knows to delete the bytes as well.
  Future<bool> forgetUnusedBlob(String sha256) async {
    final still = await (select(
      photos,
    )..where((t) => t.sha256.equals(sha256) & t.deletedAt.isNull())).get();
    if (still.isNotEmpty) return false;
    await (delete(blobs)..where((t) => t.sha256.equals(sha256))).go();
    return true;
  }
}
