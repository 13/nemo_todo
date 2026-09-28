import 'dart:math';

import 'package:nemo/utils/dates.dart';
import 'package:nemo_core/nemo_core.dart';

/// What the daily list says on one morning.
class Digest {
  const Digest({
    required this.todayCount,
    required this.overdueCount,
    required this.lines,
    required this.more,
  });

  final int todayCount;
  final int overdueCount;

  /// Titles shown when the notification is expanded, overdue first.
  final List<String> lines;

  /// Tasks not in [lines].
  final int more;
}

/// How many titles an expanded daily list shows.
const digestMaxLines = 6;

/// The daily list for the morning of [fireAt], or null when nothing is due
/// or overdue then.
///
/// [tasks] come in Today's order; that order is kept within the overdue
/// tasks and within today's. Overdue means due before [fireAt]'s day, so a
/// task due at 07:00 counts as today's in an 08:00 list.
Digest? buildDigest(List<Task> tasks, DateTime fireAt) {
  final today = dayStartMs(fireAt);
  final tomorrow = dayStartMsFrom(fireAt, 1);
  final overdue = <Task>[];
  final onDay = <Task>[];
  for (final task in tasks) {
    final dueAt = task.dueAt;
    if (task.done || task.isDeleted || dueAt == null || dueAt >= tomorrow) {
      continue;
    }
    (dueAt < today ? overdue : onDay).add(task);
  }
  final ordered = [...overdue, ...onDay];
  if (ordered.isEmpty) return null;
  final shown = min(ordered.length, digestMaxLines);
  return Digest(
    todayCount: onDay.length,
    overdueCount: overdue.length,
    lines: [for (final t in ordered.take(shown)) t.title],
    more: ordered.length - shown,
  );
}
