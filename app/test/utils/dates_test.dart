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
