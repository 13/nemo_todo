import 'package:nemo_core/nemo_core.dart';
import 'package:test/test.dart';

void main() {
  int at(int y, int m, int d, [int h = 9]) =>
      DateTime(y, m, d, h).millisecondsSinceEpoch;

  DateTime next(int due, Repeat rule, DateTime after) =>
      DateTime.fromMillisecondsSinceEpoch(
        rule.nextDueAt(dueAt: due, after: after),
      );

  group('parsing', () {
    test('reads the rules it knows and refuses the rest', () {
      expect(Repeat.tryParse('weekly'), Repeats.weekly);
      expect(Repeat.tryParse(' Weekly '), Repeats.weekly);
      expect(Repeat.tryParse('weekdays'), Repeats.weekdays);
      expect(Repeat.tryParse('every:2w'), Repeats.fortnightly);
      expect(Repeat.tryParse('every:3d'), const EveryRepeat(3, RepeatUnit.day));
      expect(
        Repeat.tryParse('monthly:last-fri'),
        const NthWeekdayRepeat(
          ordinal: NthWeekdayRepeat.last,
          weekday: DateTime.friday,
        ),
      );
      expect(
        Repeat.tryParse('monthly:2nd-tue'),
        const NthWeekdayRepeat(ordinal: 2, weekday: DateTime.tuesday),
      );

      // A rule from a version that knows more than this one reads as
      // nothing rather than as something wrong, and the column keeps it.
      for (final input in [
        null,
        '',
        'fortnightly',
        'every:',
        'every:2x',
        'every:0w',
        'every:xw',
        'monthly:last',
        'monthly:6th-fri',
        'monthly:last-xyz',
      ]) {
        expect(Repeat.tryParse(input), isNull, reason: '$input');
      }
    });

    test('every rule survives a round trip through its text', () {
      for (final rule in [
        Repeats.daily,
        Repeats.weekly,
        Repeats.monthly,
        Repeats.yearly,
        Repeats.weekdays,
        Repeats.fortnightly,
        const EveryRepeat(3, RepeatUnit.day),
        const EveryRepeat(6, RepeatUnit.month),
        const EveryRepeat(2, RepeatUnit.year),
        const NthWeekdayRepeat(
          ordinal: NthWeekdayRepeat.last,
          weekday: DateTime.friday,
        ),
        const NthWeekdayRepeat(ordinal: 1, weekday: DateTime.monday),
      ]) {
        expect(Repeat.tryParse(rule.encode()), rule, reason: rule.encode());
      }
    });

    test('an interval of one keeps the plain name it had before', () {
      expect(Repeats.daily.encode(), 'daily');
      expect(Repeats.weekly.encode(), 'weekly');
      expect(Repeats.monthly.encode(), 'monthly');
      expect(Repeats.yearly.encode(), 'yearly');
      expect(Repeats.fortnightly.encode(), 'every:2w');
    });
  });

  group('every', () {
    test('moves one step on, keeping the time of day', () {
      final now = DateTime(2026, 9, 8);
      expect(next(at(2026, 9, 8), Repeats.daily, now), DateTime(2026, 9, 9, 9));
      expect(
        next(at(2026, 9, 8), Repeats.weekly, now),
        DateTime(2026, 9, 15, 9),
      );
      expect(
        next(at(2026, 9, 8), Repeats.monthly, now),
        DateTime(2026, 10, 8, 9),
      );
      expect(
        next(at(2026, 9, 8), Repeats.yearly, now),
        DateTime(2027, 9, 8, 9),
      );
      expect(
        next(at(2026, 9, 8), Repeats.fortnightly, now),
        DateTime(2026, 9, 22, 9),
      );
    });

    test('counts from the due date, not from when it was ticked off', () {
      // Due on a Tuesday, completed on the Friday two weeks later: the next
      // one is still a Tuesday, and it is in the future.
      final completedAt = DateTime(2026, 9, 25, 16);
      final result = next(at(2026, 9, 8), Repeats.weekly, completedAt);
      expect(result, DateTime(2026, 9, 29, 9));
      expect(result.weekday, DateTime.tuesday);
      expect(result.isAfter(completedAt), isTrue);
    });

    test('a fortnightly rule keeps its own fortnight', () {
      // Late by a month: it lands on a fortnight boundary counted from the
      // original date, not a fortnight from today.
      final result = next(
        at(2026, 9, 8),
        Repeats.fortnightly,
        DateTime(2026, 10, 10),
      );
      expect(result, DateTime(2026, 10, 20, 9));
    });

    test('a monthly rule lands inside a shorter month and comes back', () {
      final jan31 = at(2026, 1, 31);
      expect(
        next(jan31, Repeats.monthly, DateTime(2026, 1, 31)),
        DateTime(2026, 2, 28, 9),
      );
      expect(
        next(jan31, Repeats.monthly, DateTime(2026, 2, 28, 12)),
        DateTime(2026, 3, 31, 9),
        reason: 'the 31st is not lost once a short month is behind it',
      );
    });

    test('the 29th of February falls back to the 28th', () {
      expect(
        next(at(2024, 2, 29), Repeats.yearly, DateTime(2024, 3, 1, 12)),
        DateTime(2025, 2, 28, 9),
      );
    });
  });

  group('weekdays', () {
    test('skips the weekend rather than landing on it', () {
      final friday = at(2026, 9, 11);
      expect(DateTime.fromMillisecondsSinceEpoch(friday).weekday, 5);
      expect(
        next(friday, Repeats.weekdays, DateTime(2026, 9, 11, 10)),
        DateTime(2026, 9, 14, 9),
      );
      expect(
        next(at(2026, 9, 14), Repeats.weekdays, DateTime(2026, 9, 14, 10)),
        DateTime(2026, 9, 15, 9),
      );
    });

    test('catches up to a weekday when it was left late', () {
      final result = next(
        at(2026, 9, 11),
        Repeats.weekdays,
        DateTime(2026, 9, 19, 12),
      );
      expect(result, DateTime(2026, 9, 21, 9), reason: 'the Monday after');
      expect(result.weekday, DateTime.monday);
    });
  });

  group('nth weekday of the month', () {
    const lastFriday = NthWeekdayRepeat(
      ordinal: NthWeekdayRepeat.last,
      weekday: DateTime.friday,
    );

    test('finds the last one whether the month has four or five', () {
      expect(
        next(at(2026, 9, 25), lastFriday, DateTime(2026, 9, 25, 12)),
        DateTime(2026, 10, 30, 9),
      );
      expect(
        next(at(2026, 10, 30), lastFriday, DateTime(2026, 10, 30, 12)),
        DateTime(2026, 11, 27, 9),
      );
    });

    test('counts from the start for an ordinal', () {
      const secondTuesday = NthWeekdayRepeat(
        ordinal: 2,
        weekday: DateTime.tuesday,
      );
      final result = next(
        at(2026, 9, 8),
        secondTuesday,
        DateTime(2026, 9, 8, 12),
      );
      expect(result, DateTime(2026, 10, 13, 9));
      expect(result.weekday, DateTime.tuesday);
    });

    test('skips ahead when it was left for months', () {
      final result = next(
        at(2026, 9, 25),
        lastFriday,
        DateTime(2026, 12, 15, 12),
      );
      expect(result, DateTime(2026, 12, 25, 9));
      expect(result.weekday, DateTime.friday);
    });
  });
}
