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

    test('refuses an hours:minutes total that would overflow int64', () {
      // hours * 60 lands just at int64.max; one more hour overflows it.
      // (9223372036854775807 - 7, not the literal, so it stays exact when
      // this file is analyzed for web compilation.)
      expect(parseMinutes('153722867280912930:00'), 9223372036854775807 - 7);
      expect(parseMinutes('153722867280912931:00'), isNull);
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

    test(
      'reads exactly at the max-safe-integer boundary and refuses past it',
      () {
        // 9007199254740991 minor units == 2^53 - 1, the largest int a double
        // represents exactly; one minor unit further can no longer be
        // trusted to round-trip precisely.
        expect(
          parseMinorUnits('90071992547409.91', locale: 'en'),
          9007199254740991,
        );
        expect(parseMinorUnits('90071992547409.99', locale: 'en'), isNull);
      },
    );
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
