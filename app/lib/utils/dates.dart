/// Date helpers. Due times are epoch milliseconds; a task without a time of
/// day is stored as the local midnight of its calendar day.
library;

DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

int dayStartMs(DateTime local) => startOfDay(local).millisecondsSinceEpoch;

/// Local midnight of the day [daysFromNow] days after [now].
///
/// Counted in calendar days rather than 24-hour spans: the day the clocks
/// change lasts 23 or 25 hours, and a day's worth of hours from its midnight
/// lands at 01:00 of the next day or 23:00 of the same one.
int dayStartMsFrom(DateTime now, int daysFromNow) =>
    DateTime(now.year, now.month, now.day + daysFromNow).millisecondsSinceEpoch;

/// Days between the calendar day of [dueAt] and the day of [now]; negative
/// when the due day is in the past.
int daysFromToday(int dueAt, DateTime now) {
  final due = DateTime.fromMillisecondsSinceEpoch(dueAt);
  // Compared as UTC dates, where every day is 24 hours long, so a 23-hour
  // day still counts as one.
  return DateTime.utc(
    due.year,
    due.month,
    due.day,
  ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
}

/// A task is overdue when its time (or, without a time, its day) has passed.
bool isOverdue({
  required int? dueAt,
  required bool hasTime,
  required DateTime now,
}) {
  if (dueAt == null) return false;
  return hasTime ? dueAt < now.millisecondsSinceEpoch : dueAt < dayStartMs(now);
}

/// Combines a calendar day with an optional time of day into epoch ms.
int composeDue(DateTime day, {int? hour, int? minute}) => DateTime(
  day.year,
  day.month,
  day.day,
  hour ?? 0,
  minute ?? 0,
).millisecondsSinceEpoch;
