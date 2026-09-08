import 'package:nemo_core/nemo_core.dart';
import 'package:test/test.dart';

void main() {
  int at(int y, int m, int d, [int h = 9]) =>
      DateTime(y, m, d, h).millisecondsSinceEpoch;

  DateTime next(int due, RepeatRule rule, DateTime after) =>
      DateTime.fromMillisecondsSinceEpoch(
        nextDueAt(dueAt: due, rule: rule, after: after),
      );

  test('parses the rules it knows and refuses the rest', () {
    expect(RepeatRule.tryParse('weekly'), RepeatRule.weekly);
    expect(RepeatRule.tryParse(null), isNull);
    expect(RepeatRule.tryParse('fortnightly'), isNull);
    expect(RepeatRule.tryParse(''), isNull);
  });

  test('moves one step on, keeping the time of day', () {
    final now = DateTime(2026, 9, 8);
    expect(
      next(at(2026, 9, 8), RepeatRule.daily, now),
      DateTime(2026, 9, 9, 9),
    );
    expect(
      next(at(2026, 9, 8), RepeatRule.weekly, now),
      DateTime(2026, 9, 15, 9),
    );
    expect(
      next(at(2026, 9, 8), RepeatRule.monthly, now),
      DateTime(2026, 10, 8, 9),
    );
    expect(
      next(at(2026, 9, 8), RepeatRule.yearly, now),
      DateTime(2027, 9, 8, 9),
    );
  });

  test('counts from the due date, not from when it was ticked off', () {
    // Due on a Tuesday, completed on the Friday two weeks later: the next
    // one is still a Tuesday, and it is in the future.
    final completedAt = DateTime(2026, 9, 25, 16);
    final result = next(at(2026, 9, 8), RepeatRule.weekly, completedAt);
    expect(result, DateTime(2026, 9, 29, 9));
    expect(result.weekday, DateTime.tuesday);
    expect(result.isAfter(completedAt), isTrue);
  });

  test('a monthly rule lands inside a shorter month and comes back', () {
    final jan31 = at(2026, 1, 31);
    final feb = next(jan31, RepeatRule.monthly, DateTime(2026, 1, 31));
    expect(feb, DateTime(2026, 2, 28, 9));
    expect(
      next(jan31, RepeatRule.monthly, DateTime(2026, 2, 28, 12)),
      DateTime(2026, 3, 31, 9),
      reason: 'the 31st is not lost once a short month is behind it',
    );
  });

  test('the 29th of February falls back to the 28th', () {
    expect(
      next(at(2024, 2, 29), RepeatRule.yearly, DateTime(2024, 3, 1)),
      DateTime(2025, 2, 28, 9),
    );
  });
}
