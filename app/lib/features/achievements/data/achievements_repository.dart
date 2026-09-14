import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/features/achievements/domain/achievement.dart';
import 'package:nemo/features/achievements/domain/completion_stats.dart';
import 'package:nemo/utils/dates.dart';

/// Achievement progress, worked out from the rows on this device, plus the
/// little the rows cannot tell: cleared days and what was celebrated.
class AchievementsRepository {
  AchievementsRepository(this._db, {DateTime Function()? now})
    : _kv = KvStore(_db),
      _now = now ?? DateTime.now;

  final AppDatabase _db;
  final KvStore _kv;
  final DateTime Function() _now;

  Future<CompletionStats> stats() async {
    final tasks = await (_db.select(
      _db.tasks,
    )..where((t) => t.done.equals(true) & t.deletedAt.isNull())).get();
    final subtasks = await (_db.select(
      _db.subtasks,
    )..where((t) => t.deletedAt.isNull())).get();
    final cleared = int.tryParse(await _kv.get(KvKeys.clearedDays) ?? '');
    return CompletionStats.from(
      tasks: tasks,
      subtasks: subtasks,
      now: _now(),
      clearedDays: cleared ?? 0,
    );
  }

  Future<List<AchievementProgress>> progress() async =>
      progressOf(await stats());

  /// Recomputed whenever a task, a subtask or the key-value store changes.
  Stream<CompletionStats> watchStats() => _db
      .customSelect('SELECT 1', readsFrom: {_db.tasks, _db.subtasks, _db.kv})
      .watch()
      .asyncMap((_) => stats());

  /// Whether nothing Today shows as open is left: nothing due today or
  /// earlier, in a list that still exists, is still to do.
  Future<bool> todayIsClear() async {
    final tomorrow = dayStartMsFrom(_now(), 1);
    final query =
        _db.select(_db.tasks).join([
            innerJoin(
              _db.lists,
              _db.lists.id.equalsExp(_db.tasks.listId),
              useColumns: false,
            ),
          ])
          ..where(
            _db.tasks.deletedAt.isNull() &
                _db.lists.deletedAt.isNull() &
                _db.tasks.done.equals(false) &
                _db.tasks.dueAt.isNotNull() &
                _db.tasks.dueAt.isSmallerThanValue(tomorrow),
          )
          ..limit(1);
    return (await query.get()).isEmpty;
  }

  /// Counts today as a cleared day, once however often it is cleared.
  Future<void> recordClearedDay() async {
    final day = startOfDay(_now()).toIso8601String().substring(0, 10);
    if (await _kv.get(KvKeys.lastClearedDay) == day) return;
    final count = int.tryParse(await _kv.get(KvKeys.clearedDays) ?? '') ?? 0;
    await _kv.set(KvKeys.clearedDays, '${count + 1}');
    await _kv.set(KvKeys.lastClearedDay, day);
  }

  /// Ids already celebrated or quietly recorded; null when never written or
  /// unreadable, which callers treat as "record, do not celebrate".
  Future<Set<String>?> seen() async {
    final raw = await _kv.get(KvKeys.achievementsSeen);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return {...decoded.whereType<String>()};
    } on FormatException {
      // Rewritten whole by the next markSeen.
    }
    return null;
  }

  Future<void> markSeen(Iterable<String> ids) async {
    final all = {...?await seen(), ...ids}.toList()..sort();
    await _kv.set(KvKeys.achievementsSeen, jsonEncode(all));
  }
}
