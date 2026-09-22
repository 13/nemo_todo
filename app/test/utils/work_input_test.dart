import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/utils/work_input.dart';

void main() {
  group('parseMinutes', () {
    test('reads bare minutes', () {
      expect(parseMinutes('90'), 90);
      expect(parseMinutes(' 90 '), 90);
      expect(parseMinutes('0'), 0);
    });

    test('reads hours and minutes however they are written', () {
      expect(parseMinutes('1h 30'), 90);
      expect(parseMinutes('1h30'), 90);
      expect(parseMinutes('1:30'), 90);
      expect(parseMinutes('2h'), 120);
      expect(parseMinutes('45m'), 45);
      expect(parseMinutes('1 h 5 m'), 65);
    });

    test('refuses what it cannot read rather than guessing', () {
      expect(parseMinutes(''), isNull);
      expect(parseMinutes('   '), isNull);
      expect(parseMinutes('a while'), isNull);
      expect(parseMinutes('-5'), isNull);
      expect(parseMinutes('1:90'), isNull, reason: '90 is not a minute count');
    });

    test('refuses digit runs too long to be an int rather than crashing', () {
      expect(parseMinutes('9' * 42), isNull);
      expect(parseMinutes('${'9' * 42}:30'), isNull);
    });

    test('reads exactly at the int64 boundary and refuses past it', () {
      expect(parseMinutes('9223372036854775807'), 9223372036854775807);
      expect(parseMinutes('9223372036854775808'), isNull);
    });

    test('refuses an hours:minutes total that would exceed the exact-JS '
        'ceiling', () {
      // hours * 60 + minutes lands exactly at 2^53 - 1 (9007199254740991,
      // the largest integer a JS number -- and so dart2js -- represents
      // exactly); one more minute pushes it past that ceiling.
      expect(parseMinutes('150119987579016:31'), 9007199254740991);
      expect(parseMinutes('150119987579016:32'), isNull);
    });
  });

  group('parseMinorUnits', () {
    test('reads a decimal in the locale that wrote it', () {
      expect(parseMinorUnits('12.50', locale: 'en'), 1250);
      expect(parseMinorUnits('12,50', locale: 'de'), 1250);
      expect(parseMinorUnits('12', locale: 'en'), 1200);
      expect(parseMinorUnits('0', locale: 'en'), 0);
      expect(parseMinorUnits('12.5', locale: 'en'), 1250);
    });

    test('refuses what it cannot read rather than guessing', () {
      expect(parseMinorUnits('', locale: 'en'), isNull);
      expect(parseMinorUnits('lots', locale: 'en'), isNull);
      expect(parseMinorUnits('-3', locale: 'en'), isNull);
      expect(
        parseMinorUnits('12.505', locale: 'en'),
        isNull,
        reason: 'more precision than the currency has',
      );
    });

    test('refuses a huge amount rather than returning a saturated value', () {
      expect(parseMinorUnits('${'9' * 42}.50', locale: 'en'), isNull);
    });

    test('reads the largest exact amount and refuses past it', () {
      // The minor units are computed from the digit strings as exact
      // integers, never through a double, so int64 itself isn't the real
      // limit -- the guard's own ceiling is: 2^53 - 1 (9007199254740991,
      // the largest integer a JS number -- and so dart2js -- represents
      // exactly) is the largest exact amount; one minor unit further can no
      // longer fit.
      expect(
        parseMinorUnits('90071992547409.91', locale: 'en'),
        9007199254740991,
      );
      expect(parseMinorUnits('90071992547409.92', locale: 'en'), isNull);
    });

    test('reads a large amount exactly, with no double in the path', () {
      // Regression for the reviewer's case: double.parse + *100 + .round()
      // lost precision here and returned ...002 instead of ...001.
      expect(
        parseMinorUnits('89999999999980.01', locale: 'en'),
        8999999999998001,
      );
    });

    test('reads every amount in a band around 2^53 exactly', () {
      // Built from exact cent values via integer/BigInt arithmetic (never a
      // formatted double) and asserted to round-trip to precisely that cent
      // value, across a band that straddles 8e15 and 9e15 -- proving
      // exactness across a range, not just at one pinned point.
      final centValues = <BigInt>[
        for (final base in [
          BigInt.from(8000000000000000),
          BigInt.from(9000000000000000),
        ])
          for (final delta in [-3, -2, -1, 0, 1, 2, 3])
            base + BigInt.from(delta),
      ];
      for (final cents in centValues) {
        final whole = cents ~/ BigInt.from(100);
        final fraction = (cents % BigInt.from(100)).abs();
        final amount = '$whole.${fraction.toString().padLeft(2, '0')}';
        expect(
          parseMinorUnits(amount, locale: 'en'),
          cents.toInt(),
          reason: '$amount should read back as exactly $cents minor units',
        );
      }
    });
  });

  group('formatting', () {
    test('formatMinutes writes hours and minutes', () {
      expect(
        formatMinutes(90, hoursLabel: 'h', minutesLabel: 'min'),
        '1 h 30 min',
      );
      expect(formatMinutes(45, hoursLabel: 'h', minutesLabel: 'min'), '45 min');
      expect(formatMinutes(120, hoursLabel: 'h', minutesLabel: 'min'), '2 h');
      expect(formatMinutes(0, hoursLabel: 'h', minutesLabel: 'min'), '0 min');
    });

    test('formatMoney writes the amount the locale would', () {
      expect(formatMoney(1250, currency: 'EUR', locale: 'de'), contains('12'));
      expect(formatMoney(1250, currency: 'EUR', locale: 'de'), contains('50'));
    });
  });
}
