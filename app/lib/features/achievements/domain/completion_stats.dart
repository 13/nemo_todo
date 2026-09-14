import 'package:nemo/utils/dates.dart';
import 'package:nemo_core/nemo_core.dart';

/// What has been done so far, as the achievements read it.
class CompletionStats {
  const CompletionStats({
    this.totalDone = 0,
    this.onTimeDone = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.clearedDays = 0,
    this.maxSubtasksOnDoneTask = 0,
  });

  /// Worked out from every task and subtask row on the device.
  ///
  /// [clearedDays] comes from outside: a cleared Today leaves no trace in
  /// the rows, so the celebration controller counts it as it happens.
  factory CompletionStats.from({
    required Iterable<Task> tasks,
    required Iterable<Subtask> subtasks,
    required DateTime now,
    int clearedDays = 0,
  }) {
    final done = [
      for (final t in tasks)
        if (t.done && !t.isDeleted) t,
    ];

    var onTime = 0;
    final days = <DateTime>{};
    for (final t in done) {
      final doneAt = t.doneAt;
      if (doneAt == null) continue;
      days.add(startOfDay(DateTime.fromMillisecondsSinceEpoch(doneAt)));
      final dueAt = t.dueAt;
      if (dueAt == null) continue;
      // Without a time of day, anywhere in the due day is on time.
      final inTime = t.dueHasTime
          ? doneAt <= dueAt
          : doneAt <
                dayStartMsFrom(DateTime.fromMillisecondsSinceEpoch(dueAt), 1);
      if (inTime) onTime++;
    }

    final perTask = <String, int>{};
    for (final s in subtasks) {
      if (!s.isDeleted) perTask[s.taskId] = (perTask[s.taskId] ?? 0) + 1;
    }
    var maxSubtasks = 0;
    for (final t in done) {
      final n = perTask[t.id] ?? 0;
      if (n > maxSubtasks) maxSubtasks = n;
    }

    return CompletionStats(
      totalDone: done.length,
      onTimeDone: onTime,
      currentStreak: _currentStreak(days, now),
      bestStreak: _bestStreak(days),
      clearedDays: clearedDays,
      maxSubtasksOnDoneTask: maxSubtasks,
    );
  }

  final int totalDone;

  /// Done tasks finished no later than their due time or due day.
  final int onTimeDone;

  /// Consecutive days with a completion, ending today -- or yesterday, so a
  /// streak is not lost before today's first task is done.
  final int currentStreak;
  final int bestStreak;

  /// Days on which this device saw Today cleared.
  final int clearedDays;

  /// The longest live checklist on a done task.
  final int maxSubtasksOnDoneTask;

  // Days are stepped by calendar date rather than by 24 hours, which is
  // what keeps a daylight saving change from breaking a streak.
  static DateTime _next(DateTime d) => DateTime(d.year, d.month, d.day + 1);
  static DateTime _previous(DateTime d) => DateTime(d.year, d.month, d.day - 1);

  static int _currentStreak(Set<DateTime> days, DateTime now) {
    final today = startOfDay(now);
    var cursor = days.contains(today) ? today : _previous(today);
    var streak = 0;
    while (days.contains(cursor)) {
      streak++;
      cursor = _previous(cursor);
    }
    return streak;
  }

  static int _bestStreak(Set<DateTime> days) {
    final sorted = days.toList()..sort();
    var best = 0;
    var run = 0;
    DateTime? last;
    for (final d in sorted) {
      run = last != null && _next(last) == d ? run + 1 : 1;
      if (run > best) best = run;
      last = d;
    }
    return best;
  }
}
