import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/celebrations/domain/motivation.dart';
import 'package:nemo/features/celebrations/ui/motivation_text.dart';
import 'package:nemo/l10n/app_localizations.dart';

const _c = MotivationContext(
  todayDone: 3,
  todayTotal: 5,
  wasInToday: true,
  firstToday: false,
  streak: 4,
  wasOverdue: false,
  cleared: false,
);

void main() {
  for (final locale in L.supportedLocales) {
    test('every variant has text in $locale', () async {
      final l = await L.delegate.load(locale);
      for (final kind in MotivationKind.values) {
        for (var v = 0; v < motivationVariants[kind]!; v++) {
          final text = motivationText(l, Motivation(kind, v), _c);
          expect(text.trim(), isNotEmpty, reason: '$kind $v');
          expect(text, isNot(contains('{')), reason: '$kind $v');
        }
      }
      for (final line in TodayLine.values) {
        for (var day = 0; day < 4; day++) {
          expect(todayLineText(l, line, day).trim(), isNotEmpty);
        }
      }
    });
  }

  test('placeholders are filled in English', () async {
    final l = await L.delegate.load(const Locale('en'));
    expect(
      motivationText(l, const Motivation(MotivationKind.progress, 0), _c),
      '3 of 5 done today.',
    );
    expect(
      motivationText(l, const Motivation(MotivationKind.progress, 1), _c),
      '3 down, 2 to go.',
    );
    expect(
      motivationText(l, const Motivation(MotivationKind.streakDay, 0), _c),
      'Day 4 in a row.',
    );
  });

  test('Italian agrees with a count of one', () async {
    final l = await L.delegate.load(const Locale('it'));
    const one = MotivationContext(
      todayDone: 1,
      todayTotal: 5,
      wasInToday: true,
      firstToday: false,
      streak: 4,
      wasOverdue: false,
      cleared: false,
    );
    String progress(int v, MotivationContext c) =>
        motivationText(l, Motivation(MotivationKind.progress, v), c);

    expect(progress(0, one), '1 su 5 fatta oggi.');
    expect(progress(0, _c), '3 su 5 fatte oggi.');
    expect(progress(1, one), '1 fatta, ne mancano 4.');
    expect(progress(1, _c), '3 fatte, ne mancano 2.');
    expect(l.todayProgressCount(1, 5), '1 su 5 fatta');
    expect(l.todayProgressCount(3, 5), '3 su 5 fatte');
    expect(
      motivationText(l, const Motivation(MotivationKind.streakDay, 0), _c),
      '4° giorno di fila.',
    );
  });

  test('an out-of-range variant falls back to the first', () async {
    final l = await L.delegate.load(const Locale('en'));
    expect(
      motivationText(l, const Motivation(MotivationKind.lastOne, 99), _c),
      'One to go.',
    );
  });
}
