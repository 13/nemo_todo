import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/achievements/domain/achievement.dart';
import 'package:nemo/features/achievements/domain/completion_stats.dart';
import 'package:nemo/l10n/app_localizations.dart';

void main() {
  test('ids are the shipped ones, unique and in order', () {
    expect(achievementCatalog.map((a) => a.id), [
      'first_done',
      'done_10',
      'done_100',
      'done_500',
      'streak_3',
      'streak_7',
      'streak_30',
      'cleared_today',
      'on_time_25',
      'checklist_5',
    ]);
  });

  test('every achievement has words in every language', () async {
    for (final locale in L.supportedLocales) {
      final l = await L.delegate.load(locale);
      for (final a in achievementCatalog) {
        expect(a.title(l), isNotEmpty, reason: '${a.id} $locale');
        expect(a.description(l), isNotEmpty, reason: '${a.id} $locale');
      }
    }
  });

  test('unlocks at the target and caps progress there', () {
    final ten = achievementCatalog.firstWhere((a) => a.id == 'done_10');
    expect(AchievementProgress(ten, 9).unlocked, isFalse);
    expect(AchievementProgress(ten, 9).fraction, closeTo(0.9, 1e-9));
    expect(AchievementProgress(ten, 10).unlocked, isTrue);
    expect(AchievementProgress(ten, 25).shown, 10);
    expect(AchievementProgress(ten, 25).fraction, 1.0);
  });

  test('progressOf reads each stat', () {
    final unlocked = progressOf(
      const CompletionStats(
        totalDone: 1,
        bestStreak: 3,
        clearedDays: 1,
        onTimeDone: 25,
        maxSubtasksOnDoneTask: 5,
      ),
    ).where((p) => p.unlocked).map((p) => p.achievement.id);
    expect(unlocked, [
      'first_done',
      'streak_3',
      'cleared_today',
      'on_time_25',
      'checklist_5',
    ]);
  });
}
