import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/utils/dates.dart';
import 'package:nemo/utils/format.dart';

void main() {
  final now = DateTime(2026, 9, 7, 10, 30);

  setUpAll(() => initializeDateFormatting('en'));

  test('day boundaries and distances', () {
    expect(dayStartMs(now), DateTime(2026, 9, 7).millisecondsSinceEpoch);
    expect(dayStartMsFrom(now, 1), DateTime(2026, 9, 8).millisecondsSinceEpoch);
    expect(
      daysFromToday(DateTime(2026, 9, 9, 23).millisecondsSinceEpoch, now),
      2,
    );
    expect(daysFromToday(DateTime(2026, 9, 5).millisecondsSinceEpoch, now), -2);
    expect(
      composeDue(DateTime(2026, 9, 7), hour: 15, minute: 5),
      DateTime(2026, 9, 7, 15, 5).millisecondsSinceEpoch,
    );
  });

  // Europe moves its clocks on 29 March and 25 October 2026, the US on
  // 8 March and 1 November, so those days last 23 or 25 hours. Every
  // expectation is a calendar date, which holds in any time zone; run the
  // file with TZ=Europe/Berlin (or TZ=America/New_York) to exercise the
  // change itself.
  group('across a daylight saving change', () {
    int midnight(int y, int m, int d) =>
        DateTime(y, m, d).millisecondsSinceEpoch;

    test('the next day starts at the next midnight', () {
      for (final (y, m, d) in [(2026, 3, 29), (2026, 10, 25)]) {
        expect(
          DateTime.fromMillisecondsSinceEpoch(
            dayStartMsFrom(DateTime(y, m, d, 12), 1),
          ),
          DateTime(y, m, d + 1),
        );
        expect(
          dayStartMsFrom(DateTime(y, m, d + 1, 12), -1),
          midnight(y, m, d),
        );
      }
      expect(dayStartMsFrom(DateTime(2026, 3, 8, 12), 1), midnight(2026, 3, 9));
      expect(
        dayStartMsFrom(DateTime(2026, 11, 1, 12), 1),
        midnight(2026, 11, 2),
      );
      expect(dayStartMsFrom(DateTime(2026, 10, 20), 7), midnight(2026, 10, 27));
      expect(
        dayStartMsFrom(DateTime(2026, 3, 29, 12), 0),
        midnight(2026, 3, 29),
      );
    });

    test('a short or long day is still one day away', () {
      expect(
        daysFromToday(midnight(2026, 3, 30), DateTime(2026, 3, 29, 12)),
        1,
      );
      expect(
        daysFromToday(midnight(2026, 3, 29), DateTime(2026, 3, 30, 12)),
        -1,
      );
      expect(
        daysFromToday(midnight(2026, 10, 26), DateTime(2026, 10, 25, 12)),
        1,
      );
      expect(
        daysFromToday(midnight(2026, 10, 25), DateTime(2026, 10, 26, 12)),
        -1,
      );
      expect(
        daysFromToday(midnight(2026, 4, 5), DateTime(2026, 3, 25, 12)),
        11,
      );
    });

    test('labels name the right day', () async {
      final l = await L.delegate.load(const Locale('en'));
      final spring = DateTime(2026, 3, 29, 12);
      expect(
        dueLabel(
          l,
          'en',
          dueAt: midnight(2026, 3, 30),
          hasTime: false,
          now: spring,
        ),
        'Tomorrow',
      );
      expect(dayHeader(l, 'en', DateTime(2026, 3, 30), spring), 'Tomorrow');
    });
  });

  test('overdue depends on whether a time is set', () {
    final earlierToday = DateTime(2026, 9, 7, 9).millisecondsSinceEpoch;
    expect(isOverdue(dueAt: earlierToday, hasTime: true, now: now), isTrue);
    expect(
      isOverdue(dueAt: dayStartMs(now), hasTime: false, now: now),
      isFalse,
    );
    expect(
      isOverdue(dueAt: dayStartMsFrom(now, -1), hasTime: false, now: now),
      isTrue,
    );
    expect(isOverdue(dueAt: null, hasTime: false, now: now), isFalse);
  });

  test('labels', () async {
    final l = await L.delegate.load(const Locale('en'));
    expect(
      dueLabel(l, 'en', dueAt: dayStartMs(now), hasTime: false, now: now),
      'Today',
    );
    expect(
      dueLabel(
        l,
        'en',
        dueAt: dayStartMsFrom(now, 1),
        hasTime: false,
        now: now,
      ),
      'Tomorrow',
    );
    expect(
      dueLabel(
        l,
        'en',
        dueAt: dayStartMsFrom(now, -1),
        hasTime: false,
        now: now,
      ),
      'Yesterday',
    );
    expect(
      dueLabel(
        l,
        'en',
        dueAt: dayStartMsFrom(now, 3),
        hasTime: false,
        now: now,
      ),
      'In 3 days',
    );
    expect(
      dueLabel(
        l,
        'en',
        dueAt: dayStartMsFrom(now, -4),
        hasTime: false,
        now: now,
      ),
      '4 days ago',
    );
    expect(
      dueLabel(
        l,
        'en',
        dueAt: dayStartMsFrom(now, 20),
        hasTime: false,
        now: now,
      ),
      'Sun, Sep 27',
    );
    // intl separates the meridiem with a narrow no-break space, so the
    // expected text is built the same way instead of being typed out.
    final threePm = DateFormat.jm('en').format(DateTime(2026, 9, 7, 15));
    expect(
      dueLabel(
        l,
        'en',
        dueAt: composeDue(now, hour: 15),
        hasTime: true,
        now: now,
      ),
      'Today · $threePm',
    );
    expect(dayHeader(l, 'en', DateTime(2026, 9, 8), now), 'Tomorrow');
    expect(dayHeader(l, 'en', DateTime(2026, 9, 10), now), 'Thu, Sep 10');
    expect(longDate('en', now), 'Monday, September 7, 2026');
  });
}
