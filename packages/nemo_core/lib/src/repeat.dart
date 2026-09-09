import 'package:meta/meta.dart';

/// How often a task comes back once it is completed.
///
/// Stored on the task as text, and parsed leniently: a rule written by a
/// newer version of the app is text this version does not recognise, so
/// [tryParse] returns null and the column keeps whatever it was told rather
/// than dropping it. That is what lets the vocabulary below grow without an
/// older client quietly stripping rules it has never heard of.
///
/// The vocabulary:
///
/// | Text | Means |
/// |---|---|
/// | `daily` `weekly` `monthly` `yearly` | every one of those |
/// | `every:3d` `every:2w` `every:6m` `every:2y` | every N days, weeks, months, years |
/// | `weekdays` | Monday to Friday |
/// | `monthly:last-fri` `monthly:2nd-tue` | that weekday of each month |
@immutable
sealed class Repeat {
  const Repeat();

  /// The rule [text] describes, or null if this version cannot read it.
  static Repeat? tryParse(String? text) {
    final value = text?.trim().toLowerCase();
    if (value == null || value.isEmpty) return null;
    return switch (value) {
      'daily' => Repeats.daily,
      'weekly' => Repeats.weekly,
      'monthly' => Repeats.monthly,
      'yearly' => Repeats.yearly,
      'weekdays' => Repeats.weekdays,
      _ when value.startsWith('every:') => _parseEvery(value.substring(6)),
      _ when value.startsWith('monthly:') => _parseNth(value.substring(8)),
      _ => null,
    };
  }

  /// The text to store, which [tryParse] reads back as this rule.
  String encode();

  /// When a task due at [dueAt] should next be due, always after [after].
  int nextDueAt({required int dueAt, required DateTime after});
}

/// The rules with a name of their own, and the ones a picker offers.
abstract final class Repeats {
  static const daily = EveryRepeat(1, RepeatUnit.day);
  static const weekly = EveryRepeat(1, RepeatUnit.week);
  static const fortnightly = EveryRepeat(2, RepeatUnit.week);
  static const monthly = EveryRepeat(1, RepeatUnit.month);
  static const yearly = EveryRepeat(1, RepeatUnit.year);
  static const weekdays = WeekdaysRepeat();
}

enum RepeatUnit {
  day('d'),
  week('w'),
  month('m'),
  year('y');

  RepeatUnit(this.letter);

  final String letter;
}

/// Every [interval] days, weeks, months or years, counted from the due date.
final class EveryRepeat extends Repeat {
  const EveryRepeat(this.interval, this.unit);

  final int interval;
  final RepeatUnit unit;

  @override
  String encode() {
    if (interval == 1) {
      return switch (unit) {
        RepeatUnit.day => 'daily',
        RepeatUnit.week => 'weekly',
        RepeatUnit.month => 'monthly',
        RepeatUnit.year => 'yearly',
      };
    }
    return 'every:$interval${unit.letter}';
  }

  @override
  int nextDueAt({required int dueAt, required DateTime after}) {
    final from = DateTime.fromMillisecondsSinceEpoch(dueAt);
    // Every step is measured from the original date rather than from the
    // step before it, so the day of the month survives a short month: taking
    // the 31st to the 28th and then stepping on from there would leave a
    // monthly task on the 28th for ever.
    var next = _step(from, 1);
    // Bounded so a corrupt or absurd date cannot spin here: a hundred years
    // of daily repeats is far past any date a person meant to type.
    for (var n = 2; !next.isAfter(after) && n <= 36500; n++) {
      next = _step(from, n);
    }
    return next.millisecondsSinceEpoch;
  }

  DateTime _step(DateTime from, int steps) {
    final count = interval * steps;
    return switch (unit) {
      RepeatUnit.day => _shiftDays(from, count),
      RepeatUnit.week => _shiftDays(from, 7 * count),
      RepeatUnit.month => _shiftMonths(from, count),
      RepeatUnit.year => _shiftMonths(from, 12 * count),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is EveryRepeat && other.interval == interval && other.unit == unit;

  @override
  int get hashCode => Object.hash(interval, unit);

  @override
  String toString() => 'Repeat(${encode()})';
}

/// Monday to Friday. The weekend is skipped rather than landed on and
/// pushed, so a task due on Friday comes back on Monday.
final class WeekdaysRepeat extends Repeat {
  const WeekdaysRepeat();

  @override
  String encode() => 'weekdays';

  @override
  int nextDueAt({required int dueAt, required DateTime after}) {
    var next = DateTime.fromMillisecondsSinceEpoch(dueAt);
    // At most a fortnight of walking gets past any `after` a repeat could
    // reasonably be counted from, and the loop below stops when it does.
    for (var guard = 0; guard < 36500; guard++) {
      next = _shiftDays(next, 1);
      if (next.weekday <= DateTime.friday && next.isAfter(after)) break;
    }
    return next.millisecondsSinceEpoch;
  }

  @override
  bool operator ==(Object other) => other is WeekdaysRepeat;

  @override
  int get hashCode => 'weekdays'.hashCode;

  @override
  String toString() => 'Repeat(weekdays)';
}

/// The nth weekday of every month: the last Friday, the second Tuesday.
///
/// [ordinal] counts from the start of the month, or is [last] for the final
/// one, which is what "the last Friday" means in a month with four of them
/// and in one with five.
final class NthWeekdayRepeat extends Repeat {
  const NthWeekdayRepeat({required this.ordinal, required this.weekday});

  /// The ordinal meaning "the last one in the month".
  static const last = -1;

  final int ordinal;

  /// `DateTime.monday` to `DateTime.sunday`.
  final int weekday;

  static const _names = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  static const Map<int, String> _ordinals = {
    1: '1st',
    2: '2nd',
    3: '3rd',
    4: '4th',
    last: 'last',
  };

  @override
  String encode() => 'monthly:${_ordinals[ordinal]}-${_names[weekday - 1]}';

  @override
  int nextDueAt({required int dueAt, required DateTime after}) {
    final from = DateTime.fromMillisecondsSinceEpoch(dueAt);
    for (var month = 1; month <= 1200; month++) {
      final candidate = _inMonth(DateTime(from.year, from.month + month), from);
      if (candidate.isAfter(after) && candidate.isAfter(from)) {
        return candidate.millisecondsSinceEpoch;
      }
    }
    return from.millisecondsSinceEpoch;
  }

  /// The occurrence inside [month], keeping the time of day from [at].
  DateTime _inMonth(DateTime month, DateTime at) {
    DateTime on(int day) => DateTime(
      month.year,
      month.month,
      day,
      at.hour,
      at.minute,
      at.second,
      at.millisecond,
    );
    if (ordinal == last) {
      final lastDay = DateTime(month.year, month.month + 1, 0).day;
      var day = lastDay;
      while (on(day).weekday != weekday) {
        day--;
      }
      return on(day);
    }
    var day = 1;
    while (on(day).weekday != weekday) {
      day++;
    }
    return on(day + 7 * (ordinal - 1));
  }

  @override
  bool operator ==(Object other) =>
      other is NthWeekdayRepeat &&
      other.ordinal == ordinal &&
      other.weekday == weekday;

  @override
  int get hashCode => Object.hash(ordinal, weekday);

  @override
  String toString() => 'Repeat(${encode()})';
}

Repeat? _parseEvery(String rest) {
  if (rest.length < 2) return null;
  final unit = RepeatUnit.values
      .where((u) => u.letter == rest.substring(rest.length - 1))
      .firstOrNull;
  final interval = int.tryParse(rest.substring(0, rest.length - 1));
  if (unit == null || interval == null || interval < 1 || interval > 999) {
    return null;
  }
  return EveryRepeat(interval, unit);
}

Repeat? _parseNth(String rest) {
  final parts = rest.split('-');
  if (parts.length != 2) return null;
  final ordinal = NthWeekdayRepeat._ordinals.entries
      .where((e) => e.value == parts.first)
      .map((e) => e.key)
      .firstOrNull;
  final weekday = NthWeekdayRepeat._names.indexOf(parts.last) + 1;
  if (ordinal == null || weekday == 0) return null;
  return NthWeekdayRepeat(ordinal: ordinal, weekday: weekday);
}

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
