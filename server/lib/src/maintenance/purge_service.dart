import 'dart:io';

import 'package:drift/drift.dart';
import 'package:logging/logging.dart';
import 'package:nemo_core/nemo_core.dart';
import 'package:nemo_server/src/blobs/blob_store.dart';
import 'package:nemo_server/src/db/server_database.dart';
import 'package:nemo_server/src/sync/sync_log_writer.dart';

final _log = Logger('nemo.purge');

/// What a purge removed, or would have removed.
class PurgeReport {
  const PurgeReport({
    this.lists = 0,
    this.tasks = 0,
    this.subtasks = 0,
    this.photos = 0,
    this.notes = 0,
    this.blobs = 0,
  });

  final int lists;
  final int tasks;
  final int subtasks;
  final int photos;
  final int notes;

  /// Blob files swept. Not part of [total]: they are bytes, not rows, and
  /// no client is waiting to be told about them.
  final int blobs;

  int get total => lists + tasks + subtasks + photos + notes;

  @override
  String toString() =>
      '$lists list(s), $tasks task(s), $subtasks subtask(s), '
      '$photos photo(s), $notes note(s), $blobs blob(s)';
}

/// Deletes rows that have been tombstoned long enough that nobody is coming
/// back for them.
///
/// A tombstone is a row: deleting a task leaves its title and notes on the
/// server for ever, and every client's first sync downloads all of them. The
/// point of a purge is to get that space back.
///
/// The catch is that the tombstone is also the only thing telling a device
/// the row is gone. Deleting it outright would mean a phone that had been
/// offline since before the delete still holds a live copy, and its next
/// sync would push that copy back and resurrect the task. So a purge does
/// not remove the record from the change log: it replaces it with a revoke,
/// which is the message that already exists for "drop your copy" and costs
/// one small row instead of a whole task. A device syncing from any cursor,
/// however old, is told to delete rather than left to guess.
class PurgeService {
  PurgeService(this._db, {required this._blobs, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final ServerDatabase _db;
  final BlobStore _blobs;
  final DateTime Function() _now;

  /// The default window. Long enough that a device switched off for a
  /// holiday has been heard from since, short enough to be worth doing.
  static const defaultRetention = Duration(days: 30);

  /// Removes everything tombstoned longer ago than [retention].
  ///
  /// With [dryRun] the counts come back and nothing is written, so a
  /// scheduled job can report before it is trusted to delete.
  Future<PurgeReport> purge({
    Duration retention = defaultRetention,
    bool dryRun = false,
  }) async {
    // Tombstones are HLC stamps, and an HLC sorts as a string exactly as it
    // sorts as a time, so "older than" is a string comparison against a
    // stamp built for the cutoff instant.
    final staleMillis = _now().subtract(retention).millisecondsSinceEpoch;
    final cutoff = Hlc(millis: staleMillis, counter: 0, node: '').toString();

    final result = await _db.transaction(() async {
      final lists = await _oldLists(cutoff);
      final tasks = await _oldTasks(cutoff);
      final subtasks = await _oldSubtasks(cutoff);

      // A purged parent takes its children with it whatever state they are
      // in: a subtask outliving its task is a row nothing can ever reach.
      final taskIds = {
        for (final t in tasks) t.id,
        for (final row in await _childTasks(lists.map((l) => l.id))) row.id,
      };
      final subtaskIds = {
        for (final s in subtasks) s.id,
        for (final row in await _childSubtasks(taskIds)) row.id,
      };
      // A purged list takes its notes with it, exactly as it takes its
      // tasks: a note surviving its list is a row nothing can ever reach.
      final noteIds = {
        for (final n in await _oldNotes(cutoff)) n.id,
        for (final row in await _childNotes(lists.map((l) => l.id))) row.id,
      };
      final photos = await _oldPhotos(cutoff);
      final photoIds = {
        for (final p in photos) p.id,
        for (final row in await _childPhotos(taskIds)) row.id,
        for (final row in await _childNotePhotos(noteIds)) row.id,
      };

      if (dryRun) {
        return (
          lists: lists.length,
          tasks: taskIds.length,
          subtasks: subtaskIds.length,
          photoIds: photoIds,
          noteIds: noteIds,
        );
      }

      // Children first, so a parent still exists to name the list a revoke
      // is addressed to. Photos are retired and deleted before their tasks
      // and notes, for the same reason; notes are retired and deleted
      // after their photos and before the lists that hold them.
      for (final id in photoIds) {
        await _retire(SyncEntity.photo, id, await _listOfPhoto(id));
      }
      for (final id in subtaskIds) {
        await _retire(SyncEntity.subtask, id, await _listOfSubtask(id));
      }
      for (final id in taskIds) {
        await _retire(SyncEntity.task, id, await _listOfTask(id));
      }
      for (final id in noteIds) {
        await _retire(SyncEntity.note, id, await _listOfNote(id));
      }
      for (final list in lists) {
        await _retire(SyncEntity.list, list.id, list.id);
      }

      await (_db.delete(_db.photos)..where((t) => t.id.isIn(photoIds))).go();
      await (_db.delete(
        _db.subtasks,
      )..where((t) => t.id.isIn(subtaskIds))).go();
      await (_db.delete(_db.tasks)..where((t) => t.id.isIn(taskIds))).go();
      await (_db.delete(_db.notes)..where((t) => t.id.isIn(noteIds))).go();
      await (_db.delete(
        _db.lists,
      )..where((t) => t.id.isIn(lists.map((l) => l.id)))).go();

      return (
        lists: lists.length,
        tasks: taskIds.length,
        subtasks: subtaskIds.length,
        photoIds: photoIds,
        noteIds: noteIds,
      );
    });

    // Blobs are swept only once the row purge's transaction above has
    // committed (see `_sweepBlobs` for why), and a dry run never sweeps at
    // all -- it instead asks `_orphanBlobs` to predict what a real run
    // would newly orphan, by treating this run's own photo deletions as
    // already having happened.
    final blobs = dryRun
        ? (await _orphanBlobs(
            staleMillis,
            excludingPhotoIds: result.photoIds,
          )).length
        : await _sweepBlobs(staleMillis);

    return PurgeReport(
      lists: result.lists,
      tasks: result.tasks,
      subtasks: result.subtasks,
      photos: result.photoIds.length,
      notes: result.noteIds.length,
      blobs: blobs,
    );
  }

  // Three near-identical queries rather than one generic helper: drift's
  // column types are per table, and the version that took a table generic
  // had to reach for the column by its SQL name and cast it.
  Future<List<TaskList>> _oldLists(String cutoff) =>
      (_db.select(_db.lists)..where(
            (t) =>
                t.deletedAt.isNotNull() &
                t.deletedAt.isSmallerThanValue(cutoff),
          ))
          .get();

  Future<List<Task>> _oldTasks(String cutoff) =>
      (_db.select(_db.tasks)..where(
            (t) =>
                t.deletedAt.isNotNull() &
                t.deletedAt.isSmallerThanValue(cutoff),
          ))
          .get();

  Future<List<Subtask>> _oldSubtasks(String cutoff) =>
      (_db.select(_db.subtasks)..where(
            (t) =>
                t.deletedAt.isNotNull() &
                t.deletedAt.isSmallerThanValue(cutoff),
          ))
          .get();

  Future<List<Task>> _childTasks(Iterable<String> listIds) async {
    final ids = listIds.toList();
    if (ids.isEmpty) return const [];
    return await (_db.select(
      _db.tasks,
    )..where((t) => t.listId.isIn(ids))).get();
  }

  Future<List<Subtask>> _childSubtasks(Iterable<String> taskIds) async {
    final ids = taskIds.toList();
    if (ids.isEmpty) return const [];
    return await (_db.select(
      _db.subtasks,
    )..where((t) => t.taskId.isIn(ids))).get();
  }

  Future<List<Note>> _oldNotes(String cutoff) =>
      (_db.select(_db.notes)..where(
            (t) =>
                t.deletedAt.isNotNull() &
                t.deletedAt.isSmallerThanValue(cutoff),
          ))
          .get();

  Future<List<Note>> _childNotes(Iterable<String> listIds) async {
    final ids = listIds.toList();
    if (ids.isEmpty) return const [];
    return await (_db.select(
      _db.notes,
    )..where((t) => t.listId.isIn(ids))).get();
  }

  Future<List<Photo>> _oldPhotos(String cutoff) =>
      (_db.select(_db.photos)..where(
            (t) =>
                t.deletedAt.isNotNull() &
                t.deletedAt.isSmallerThanValue(cutoff),
          ))
          .get();

  Future<List<Photo>> _childPhotos(Iterable<String> taskIds) async {
    final ids = taskIds.toList();
    if (ids.isEmpty) return const [];
    return await (_db.select(_db.photos)..where(
          (t) =>
              t.parentKind.equalsValue(PhotoParent.task) & t.parentId.isIn(ids),
        ))
        .get();
  }

  Future<List<Photo>> _childNotePhotos(Iterable<String> noteIds) async {
    final ids = noteIds.toList();
    if (ids.isEmpty) return const [];
    return await (_db.select(_db.photos)..where(
          (t) =>
              t.parentKind.equalsValue(PhotoParent.note) & t.parentId.isIn(ids),
        ))
        .get();
  }

  /// The list a revoke should be addressed to.
  ///
  /// Falls back to whatever the change log already said about the row: an
  /// earlier purge may have taken the parent, and a revoke has to name a
  /// list for the members of that list to receive it.
  Future<String> _listOfSubtask(String id) async {
    final subtask = await _db.subtaskById(id);
    if (subtask != null) {
      final task = await _db.taskById(subtask.taskId);
      if (task != null) return task.listId;
    }
    return await _loggedListId(SyncEntity.subtask, id);
  }

  Future<String> _listOfTask(String id) async {
    final task = await _db.taskById(id);
    return task?.listId ?? await _loggedListId(SyncEntity.task, id);
  }

  Future<String> _listOfNote(String id) async {
    final note = await _db.noteById(id);
    return note?.listId ?? await _loggedListId(SyncEntity.note, id);
  }

  Future<String> _listOfPhoto(String id) async {
    final row = await _db.photoById(id);
    if (row != null) {
      final listId = switch (row.parentKind) {
        PhotoParent.task => (await _db.taskById(row.parentId))?.listId,
        PhotoParent.note => (await _db.noteById(row.parentId))?.listId,
      };
      if (listId != null) return listId;
    }
    return await _loggedListId(SyncEntity.photo, id);
  }

  Future<String> _loggedListId(SyncEntity entity, String rowId) async {
    final entry =
        await (_db.select(_db.syncLog)
              ..where(
                (t) => t.entity.equals(entity.name) & t.rowId.equals(rowId),
              )
              ..limit(1))
            .getSingleOrNull();
    return entry?.listId ?? '';
  }

  /// Drops everything the log holds about a row and leaves one revoke.
  Future<void> _retire(SyncEntity entity, String rowId, String listId) async {
    await (_db.delete(
      _db.syncLog,
    )..where((t) => t.entity.equals(entity.name) & t.rowId.equals(rowId))).go();
    await _db.logRevoke(entity, rowId, listId: listId);
  }

  /// Blobs no live photo row names any more, old enough that they are not
  /// bytes waiting for the row that is about to claim them.
  ///
  /// [excludingPhotoIds] is how a dry run asks "what would be orphaned if
  /// these photo rows were already gone" without deleting them: a real
  /// sweep never passes it, because by the time `_sweepBlobs` calls this,
  /// the transaction that deleted those rows has already committed, and
  /// they are simply gone from `photos` already.
  ///
  /// [staleMillis] is plain epoch milliseconds, not an HLC stamp: a blob's
  /// `createdAt` is wall-clock time, not a synced row with a device clock.
  ///
  /// For a real sweep this is only a list of candidates, in hash order so a
  /// run is repeatable: it is read once, and the server keeps accepting
  /// pushes and uploads while the sweep works through it.
  Future<List<BlobRow>> _orphanBlobs(
    int staleMillis, {
    Set<String> excludingPhotoIds = const {},
  }) {
    final referenced = _db.selectOnly(_db.photos)
      ..addColumns([_db.photos.sha256]);
    if (excludingPhotoIds.isNotEmpty) {
      referenced.where(_db.photos.id.isNotIn(excludingPhotoIds));
    }
    return (_db.select(_db.blobs)
          ..where(
            (t) =>
                t.createdAt.isSmallerThanValue(staleMillis) &
                t.sha256.isNotInQuery(referenced),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.sha256)]))
        .get();
  }

  /// Deletes files and rows for every orphaned, stale blob.
  ///
  /// Runs after the row purge's transaction has committed, so a file that
  /// will not delete can never roll back the rows purged alongside it.
  ///
  /// The purge is a separate process from the server, writing the same
  /// database, so between listing the candidates and reaching one of them
  /// a `/sync` push may have named its hash, or an upload may have made it
  /// young again. No lock in this process can see that; SQLite's write
  /// lock can. So each candidate is claimed in its own transaction that
  /// opens with a conditional delete of its row, re-checking "stale and
  /// unnamed" at the moment the lock is taken. A push or upload that
  /// arrives after that waits for the transaction, and the file is deleted
  /// before it ends, so either the claim finds the blob wanted and leaves
  /// it, or it holds the lock until the bytes are gone and the uploader
  /// finds no row and stores them afresh.
  ///
  /// One transaction per blob rather than one for the sweep, so a single
  /// file that will not delete rolls back only its own row (kept for a
  /// later sweep to retry), and the server is never locked out of writing
  /// for the length of a whole sweep.
  Future<int> _sweepBlobs(int staleMillis) async {
    var swept = 0;
    for (final candidate in await _orphanBlobs(staleMillis)) {
      final hash = candidate.sha256;
      try {
        final claimed = await _db.transaction(() async {
          final referenced = _db.selectOnly(_db.photos)
            ..addColumns([_db.photos.sha256]);
          final deleted =
              await (_db.delete(_db.blobs)..where(
                    (t) =>
                        t.sha256.equals(hash) &
                        t.createdAt.isSmallerThanValue(staleMillis) &
                        t.sha256.isNotInQuery(referenced),
                  ))
                  .go();
          if (deleted == 0) return false;
          // Already-gone files are handled inside BlobStore.delete itself,
          // so a FileSystemException here is a real failure (permissions, a
          // busy disk), and letting it out of the transaction puts the row
          // back.
          await _blobs.delete(hash);
          return true;
        });
        if (claimed) swept++;
      } on FileSystemException catch (e, s) {
        _log.warning(
          'could not delete blob $hash, keeping its row for a later sweep '
          'to retry',
          e,
          s,
        );
      }
    }
    return swept;
  }
}
