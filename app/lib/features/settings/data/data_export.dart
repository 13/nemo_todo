import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/features/photos/data/photo_store.dart';
import 'package:nemo_core/nemo_core.dart';

/// What an export produced.
class ExportResult {
  const ExportResult(this.bytes, {required this.photosLeftOut});

  /// The zip to save.
  final Uint8List bytes;

  /// Photos whose bytes this device does not hold -- on the web they are
  /// fetched when shown and not kept -- and so are missing from the file.
  final int photosLeftOut;
}

/// Lists, tasks, subtasks and their photos as a file a person can keep, and
/// back again.
///
/// The file is a zip: the rows as JSON in [jsonEntry], and each picture's
/// bytes under [photoEntry], named by their hash like everywhere else.
class DataExport {
  DataExport(
    this._db,
    this._clock,
    this._photos, {
    this.reminders = const NoopReminderScheduler(),
  });

  static const format = 'nemo-export';

  /// 1 was a bare JSON file without photos; it still imports.
  static const version = 2;
  static const jsonEntry = 'nemo-export.json';
  static String photoEntry(String sha256) => 'photos/$sha256';

  final AppDatabase _db;
  final HlcClock _clock;
  final PhotoStore _photos;
  final ReminderScheduler reminders;

  /// Everything alive on this device, as a zip.
  Future<ExportResult> export({required DateTime now}) async {
    final lists = await (_db.select(
      _db.lists,
    )..where((t) => t.deletedAt.isNull())).get();
    final listIds = {for (final l in lists) l.id};
    final tasks = [
      for (final t in await (_db.select(
        _db.tasks,
      )..where((t) => t.deletedAt.isNull())).get())
        if (listIds.contains(t.listId)) t,
    ];
    final taskIds = {for (final t in tasks) t.id};
    final subtasks = [
      for (final s in await (_db.select(
        _db.subtasks,
      )..where((t) => t.deletedAt.isNull())).get())
        if (taskIds.contains(s.taskId)) s,
    ];
    final photos = <Photo>[];
    final pictures = <String, Uint8List>{};
    var leftOut = 0;
    for (final photo in await (_db.select(
      _db.photos,
    )..where((t) => t.deletedAt.isNull())).get()) {
      if (!taskIds.contains(photo.taskId)) continue;
      final bytes = pictures[photo.sha256] ?? await _photos.get(photo.sha256);
      if (bytes == null) {
        leftOut++;
        continue;
      }
      photos.add(photo);
      pictures[photo.sha256] = bytes;
    }
    final json = const JsonEncoder.withIndent('  ').convert({
      'format': format,
      'version': version,
      'exportedAt': now.toUtc().toIso8601String(),
      'lists': [for (final l in lists) l.toJson()],
      'tasks': [for (final t in tasks) t.toJson()],
      'subtasks': [for (final s in subtasks) s.toJson()],
      'photos': [for (final p in photos) p.toJson()],
    });
    final archive = Archive()..addFile(ArchiveFile.string(jsonEntry, json));
    for (final entry in pictures.entries) {
      // Pictures are already compressed (JPEG); deflating them again barely
      // shrinks them further and costs time, so they are stored as-is.
      archive.addFile(
        ArchiveFile.noCompress(
          photoEntry(entry.key),
          entry.value.length,
          entry.value,
        ),
      );
    }
    return ExportResult(
      ZipEncoder().encodeBytes(archive),
      photosLeftOut: leftOut,
    );
  }

  /// Adds whatever [bytes] holds that this device does not, and answers how
  /// many rows that was. Throws [FormatException] for anything that is not
  /// an export this version can read, before writing a single row.
  ///
  /// A row that is already here and alive is left alone, whatever the file
  /// says: the file is a snapshot from some earlier moment, and the row here
  /// may have been edited since. A row that is missing, or was deleted, comes
  /// back -- which is the point of importing -- with a fresh stamp, so the
  /// sync carries it to the server instead of losing to the deletion.
  Future<int> import(Uint8List bytes) async {
    final parsed = _parse(bytes);
    final putHashes = <String>[];
    try {
      return await _db.transaction(() async {
        var added = 0;
        for (final list in parsed.lists) {
          if (_live(await _db.listById(list.id))) continue;
          await _db.upsertList(
            list.copyWith(updatedAt: _stamp(), deletedAt: null),
          );
          added++;
        }
        for (final task in parsed.tasks) {
          if (!_live(await _db.listById(task.listId))) continue;
          if (_live(await _db.taskById(task.id))) continue;
          final restored = task.copyWith(updatedAt: _stamp(), deletedAt: null);
          await _db.upsertTask(restored);
          await reminders.sync(restored);
          added++;
        }
        for (final subtask in parsed.subtasks) {
          if (!_live(await _db.taskById(subtask.taskId))) continue;
          if (_live(await _db.subtaskById(subtask.id))) continue;
          await _db.upsertSubtask(
            subtask.copyWith(updatedAt: _stamp(), deletedAt: null),
          );
          added++;
        }
        for (final photo in parsed.photos) {
          if (!_live(await _db.taskById(photo.taskId))) continue;
          if (_live(await _db.photoById(photo.id))) continue;
          final file = parsed.pictures[photo.sha256];
          if (file == null) continue;
          // Read only now that the row is actually going to be imported --
          // most entries in a large export never reach this point.
          Uint8List? bytes;
          try {
            bytes = file.readBytes();
          } on Object {
            bytes = null;
          }
          // A picture that is missing, fails to read, or is not what its
          // row says it is, is left out rather than restored as a broken
          // image.
          if (bytes == null ||
              sha256.convert(bytes).toString() != photo.sha256) {
            continue;
          }
          // The same order adding a photo uses: bytes known and protected
          // before the row, so a sync never sends the row ahead of them.
          await _photos.put(photo.sha256, bytes);
          putHashes.add(photo.sha256);
          await _photos.pin(photo.sha256);
          await _db.rememberBlob(
            photo.sha256,
            byteSize: bytes.length,
            state: 'pendingUpload',
          );
          await _db.upsertPhoto(
            photo.copyWith(updatedAt: _stamp(), deletedAt: null),
          );
          added++;
        }
        return added;
      });
    } on Object catch (error, stack) {
      // The transaction rolled back the rows, but not any bytes this
      // attempt put -- clean up whichever of those no other row now
      // accounts for, so a failed import never leaves orphaned bytes
      // pinned in memory or on disk.
      for (final hash in putHashes) {
        final row = await (_db.select(
          _db.blobs,
        )..where((b) => b.sha256.equals(hash))).getSingleOrNull();
        // A row now exists: the device already knew these bytes before this
        // import (a synced download, or a photo added earlier). Leave them
        // pinned on purpose -- this import cannot tell whether the hash was
        // already pinned (a photo still waiting to upload), and unpinning it
        // could drop the only protection its bytes have.
        //
        // This check and the removal below are not atomic with other
        // writers: a concurrent add or download landing on the same bytes
        // between them could lose those bytes. Accepted, because it takes
        // identical bytes arriving within milliseconds of a failed import.
        if (row != null) continue;
        try {
          await _photos.unpin(hash);
        } on Object {
          // A cleanup failure must never hide the original error below.
        }
        try {
          await _photos.remove(hash);
        } on Object {
          // Same as above.
        }
      }
      Error.throwWithStackTrace(error, stack);
    }
  }

  String _stamp() => _clock.now().toString();

  static bool _live(SyncRow? row) => row != null && row.deletedAt == null;

  static _Parsed _parse(Uint8List bytes) {
    try {
      final String text;
      final pictures = <String, ArchiveFile>{};
      if (_isZip(bytes)) {
        final archive = ZipDecoder().decodeBytes(bytes);
        final json = archive.findFile(jsonEntry)?.readBytes();
        if (json == null) throw const FormatException('not a nemo export');
        text = utf8.decode(json);
        const prefix = 'photos/';
        for (final file in archive.files) {
          if (!file.name.startsWith(prefix) || file.name.endsWith('/')) {
            continue;
          }
          // Just the name and the (still-compressed) file handle -- its
          // bytes are read later, only for a row that is actually imported.
          pictures[file.name.substring(prefix.length)] = file;
        }
      } else {
        text = utf8.decode(bytes);
      }
      final json = jsonDecode(text);
      if (json is! Map<String, dynamic> ||
          json['format'] != format ||
          json['version'] is! int ||
          (json['version'] as int) > version) {
        throw const FormatException('not a nemo export');
      }
      List<Map<String, dynamic>> rows(String key) => [
        for (final row in json[key] as List<dynamic>? ?? const [])
          row as Map<String, dynamic>,
      ];
      return (
        lists: [for (final r in rows('lists')) TaskList.fromJson(r)],
        tasks: [for (final r in rows('tasks')) Task.fromJson(r)],
        subtasks: [for (final r in rows('subtasks')) Subtask.fromJson(r)],
        photos: [for (final r in rows('photos')) Photo.fromJson(r)],
        pictures: pictures,
      );
    } on FormatException {
      rethrow;
    } on Object catch (e) {
      // A cast or a missing field in a row: the file is not what it claims.
      throw FormatException('not a nemo export: $e');
    }
  }

  /// A zip file starts with the local file header signature `PK\x03\x04`.
  static bool _isZip(Uint8List bytes) =>
      bytes.length >= 4 &&
      bytes[0] == 0x50 &&
      bytes[1] == 0x4b &&
      bytes[2] == 0x03 &&
      bytes[3] == 0x04;
}

typedef _Parsed = ({
  List<TaskList> lists,
  List<Task> tasks,
  List<Subtask> subtasks,
  List<Photo> photos,
  Map<String, ArchiveFile> pictures,
});
