/// How often a task comes back once it is completed.
///
/// Stored on the task as the plain name, so a rule written by a newer
/// version of the app survives a round trip through an older one instead of
/// being dropped on the floor: [tryParse] returns null for a name it does
/// not know, and the column keeps whatever it was told.
enum RepeatRule {
  daily,
  weekly,
  monthly,
  yearly;

  static RepeatRule? tryParse(String? name) =>
      name == null ? null : RepeatRule.values.asNameMap()[name];
}

/// When a task due at [dueAt] should next be due under [rule].
///
/// Counts from the due date rather than from the moment it was ticked off,
/// so a weekly task stays on its weekday however late it is completed. A
/// task finished long after it was due would otherwise come back already
/// overdue, so the rule is applied until the result is in the future.
///
/// The time of day is carried over untouched, and a monthly or yearly rule
/// lands on the last day of a shorter month rather than spilling into the
/// next one: the 31st repeated monthly is the 28th in February, and the
/// 31st again in March.
int nextDueAt({
  required int dueAt,
  required RepeatRule rule,
  required DateTime after,
}) {
  final from = DateTime.fromMillisecondsSinceEpoch(dueAt);
  // Every step is measured from the original date rather than from the
  // step before it, so the day of the month survives a short month: taking
  // the 31st to the 28th and then stepping on from there would leave a
  // monthly task on the 28th for ever.
  var next = _advance(from, rule, 1);
  // Bounded so a corrupt or absurd date cannot spin here: a hundred years
  // of daily repeats is far past any date a person meant to type.
  for (var step = 2; !next.isAfter(after) && step <= 36500; step++) {
    next = _advance(from, rule, step);
  }
  return next.millisecondsSinceEpoch;
}

DateTime _advance(DateTime from, RepeatRule rule, int steps) => switch (rule) {
  RepeatRule.daily => _shiftDays(from, steps),
  RepeatRule.weekly => _shiftDays(from, 7 * steps),
  RepeatRule.monthly => _shiftMonths(from, steps),
  RepeatRule.yearly => _shiftMonths(from, 12 * steps),
};

/// Adds whole days, keeping the wall-clock time across a daylight saving
/// change: adding 24 hours to the day the clocks go forward would land an
/// hour out and drift further every week.
DateTime _shiftDays(DateTime from, int days) => DateTime(
  from.year,
  from.month,
  from.day + days,
  from.hour,
  from.minute,
  from.second,
  from.millisecond,
);

DateTime _shiftMonths(DateTime from, int months) {
  final target = DateTime(from.year, from.month + months);
  final lastDay = DateTime(target.year, target.month + 1, 0).day;
  return DateTime(
    target.year,
    target.month,
    from.day < lastDay ? from.day : lastDay,
    from.hour,
    from.minute,
    from.second,
    from.millisecond,
  );
}
