import 'package:nemo/features/celebrations/domain/motivation.dart';
import 'package:nemo/l10n/app_localizations.dart';

/// The words for [m]. An index past the kind's variants -- which the
/// chooser never produces -- falls back to the first.
String motivationText(L l, Motivation m, MotivationContext c) {
  final variants = switch (m.kind) {
    MotivationKind.dayCleared => [
      l.motivationDayCleared0,
      l.motivationDayCleared1,
      l.motivationDayCleared2,
      l.motivationDayCleared3,
    ],
    MotivationKind.lastOne => [
      l.motivationLastOne0,
      l.motivationLastOne1,
      l.motivationLastOne2,
    ],
    MotivationKind.halfway => [
      l.motivationHalfway0,
      l.motivationHalfway1,
      l.motivationHalfway2,
    ],
    MotivationKind.streakDay => [
      l.motivationStreakDay0(c.streak),
      l.motivationStreakDay1(c.streak),
      l.motivationStreakDay2(c.streak),
    ],
    MotivationKind.firstOfDay => [
      l.motivationFirstOfDay0,
      l.motivationFirstOfDay1,
      l.motivationFirstOfDay2,
      l.motivationFirstOfDay3,
    ],
    MotivationKind.overdue => [
      l.motivationOverdue0,
      l.motivationOverdue1,
      l.motivationOverdue2,
    ],
    MotivationKind.progress => [
      l.motivationProgress0(c.todayDone, c.todayTotal),
      l.motivationProgress1(c.todayDone, c.todayLeft),
    ],
    MotivationKind.generic => [
      l.motivationGeneric0,
      l.motivationGeneric1,
      l.motivationGeneric2,
      l.motivationGeneric3,
      l.motivationGeneric4,
      l.motivationGeneric5,
      l.motivationGeneric6,
      l.motivationGeneric7,
      l.motivationGeneric8,
      l.motivationGeneric9,
      l.motivationGeneric10,
      l.motivationGeneric11,
    ],
  };
  return m.variant >= 0 && m.variant < variants.length
      ? variants[m.variant]
      : variants.first;
}

/// The Today header's line, when it has one.
enum TodayLine { welcomeBack, freshStart, allClear }

/// [line]'s words, the variant chosen by [dayOfYear] so it stays the same
/// all day rather than changing on every rebuild.
String todayLineText(L l, TodayLine line, int dayOfYear) {
  final variants = switch (line) {
    TodayLine.welcomeBack => [l.todayWelcomeBack0, l.todayWelcomeBack1],
    TodayLine.freshStart => [
      l.todayFreshStart0,
      l.todayFreshStart1,
      l.todayFreshStart2,
    ],
    TodayLine.allClear => [l.todayAllClear],
  };
  return variants[dayOfYear % variants.length];
}
