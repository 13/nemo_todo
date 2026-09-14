import 'dart:convert';

import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo_core/nemo_core.dart';

/// Lists, tasks and subtasks as a file a person can keep, and back again.
///
/// Photos stay out: their bytes would make a file of megabytes out of one of
/// kilobytes, and the server's own backup already holds them.
class DataExport {
  DataExport(
    this._db,
    this._clock, {
    this.reminders = const NoopReminderScheduler(),
  });

  static const format = 'nemo-export';
  static const version = 1;

  final AppDatabase _db;
  final HlcClock _clock;
  final ReminderScheduler reminders;

  /// Everything alive on this device, as JSON.
  Future<String> export({required DateTime now}) async {
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
    return const JsonEncoder.withIndent('  ').convert({
      'format': format,
      'version': version,
      'exportedAt': now.toUtc().toIso8601String(),
      'lists': [for (final l in lists) l.toJson()],
      'tasks': [for (final t in tasks) t.toJson()],
      'subtasks': [for (final s in subtasks) s.toJson()],
    });
  }

  /// Adds whatever [text] holds that this device does not, and answers how
  /// many rows that was. Throws [FormatException] for anything that is not
  /// an export this version can read, before writing a single row.
  ///
  /// A row that is already here and alive is left alone, whatever the file
  /// says: the file is a snapshot from some earlier moment, and the row here
  /// may have been edited since. A row that is missing, or was deleted, comes
  /// back -- which is the point of importing -- with a fresh stamp, so the
  /// sync carries it to the server instead of losing to the deletion.
  Future<int> import(String text) async {
    final (lists, tasks, subtasks) = _parse(text);
    return await _db.transaction(() async {
      var added = 0;
      for (final list in lists) {
        if (_live(await _db.listById(list.id))) continue;
        await _db.upsertList(
          list.copyWith(updatedAt: _stamp(), deletedAt: null),
        );
        added++;
      }
      for (final task in tasks) {
        if (!_live(await _db.listById(task.listId))) continue;
        if (_live(await _db.taskById(task.id))) continue;
        final restored = task.copyWith(updatedAt: _stamp(), deletedAt: null);
        await _db.upsertTask(restored);
        await reminders.sync(restored);
        added++;
      }
      for (final subtask in subtasks) {
        if (!_live(await _db.taskById(subtask.taskId))) continue;
        if (_live(await _db.subtaskById(subtask.id))) continue;
        await _db.upsertSubtask(
          subtask.copyWith(updatedAt: _stamp(), deletedAt: null),
        );
        added++;
      }
      return added;
    });
  }

  String _stamp() => _clock.now().toString();

  static bool _live(SyncRow? row) => row != null && row.deletedAt == null;

  static (List<TaskList>, List<Task>, List<Subtask>) _parse(String text) {
    try {
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
        [for (final r in rows('lists')) TaskList.fromJson(r)],
        [for (final r in rows('tasks')) Task.fromJson(r)],
        [for (final r in rows('subtasks')) Subtask.fromJson(r)],
      );
    } on FormatException {
      rethrow;
    } on Object catch (e) {
      // A cast or a missing field in a row: the file is not what it claims.
      throw FormatException('not a nemo export: $e');
    }
  }
}
