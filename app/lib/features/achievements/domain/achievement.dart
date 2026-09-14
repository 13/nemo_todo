import 'package:flutter/material.dart';
import 'package:nemo/features/achievements/domain/completion_stats.dart';
import 'package:nemo/l10n/app_localizations.dart';

/// Something to reach, read off [CompletionStats].
class Achievement {
  const Achievement({
    required this.id,
    required this.icon,
    required this.target,
    required this.value,
    required this.title,
    required this.description,
  });

  /// Stored in the set of achievements already celebrated; never renamed.
  final String id;
  final IconData icon;
  final int target;
  final int Function(CompletionStats stats) value;
  final String Function(L l) title;
  final String Function(L l) description;
}

/// How far along one achievement is.
class AchievementProgress {
  const AchievementProgress(this.achievement, this.value);

  final Achievement achievement;
  final int value;

  bool get unlocked => value >= achievement.target;

  /// [value], capped at the target, for "7 / 10".
  int get shown => value < achievement.target ? value : achievement.target;

  double get fraction => shown / achievement.target;
}

/// Every achievement, in the order the achievements screen shows them.
///
/// Streaks read the best streak, so one reached stays reached.
final List<Achievement> achievementCatalog = [
  Achievement(
    id: 'first_done',
    icon: Icons.check_circle_outline_rounded,
    target: 1,
    value: (s) => s.totalDone,
    title: (l) => l.achievementFirstDoneTitle,
    description: (l) => l.achievementFirstDoneDescription,
  ),
  Achievement(
    id: 'done_10',
    icon: Icons.trending_up_rounded,
    target: 10,
    value: (s) => s.totalDone,
    title: (l) => l.achievementDone10Title,
    description: (l) => l.achievementDone10Description,
  ),
  Achievement(
    id: 'done_100',
    icon: Icons.military_tech_outlined,
    target: 100,
    value: (s) => s.totalDone,
    title: (l) => l.achievementDone100Title,
    description: (l) => l.achievementDone100Description,
  ),
  Achievement(
    id: 'done_500',
    icon: Icons.rocket_launch_outlined,
    target: 500,
    value: (s) => s.totalDone,
    title: (l) => l.achievementDone500Title,
    description: (l) => l.achievementDone500Description,
  ),
  Achievement(
    id: 'streak_3',
    icon: Icons.local_fire_department_outlined,
    target: 3,
    value: (s) => s.bestStreak,
    title: (l) => l.achievementStreak3Title,
    description: (l) => l.achievementStreak3Description,
  ),
  Achievement(
    id: 'streak_7',
    icon: Icons.whatshot_outlined,
    target: 7,
    value: (s) => s.bestStreak,
    title: (l) => l.achievementStreak7Title,
    description: (l) => l.achievementStreak7Description,
  ),
  Achievement(
    id: 'streak_30',
    icon: Icons.event_available_outlined,
    target: 30,
    value: (s) => s.bestStreak,
    title: (l) => l.achievementStreak30Title,
    description: (l) => l.achievementStreak30Description,
  ),
  Achievement(
    id: 'cleared_today',
    icon: Icons.wb_sunny_outlined,
    target: 1,
    value: (s) => s.clearedDays,
    title: (l) => l.achievementClearedTodayTitle,
    description: (l) => l.achievementClearedTodayDescription,
  ),
  Achievement(
    id: 'on_time_25',
    icon: Icons.schedule_rounded,
    target: 25,
    value: (s) => s.onTimeDone,
    title: (l) => l.achievementOnTime25Title,
    description: (l) => l.achievementOnTime25Description,
  ),
  Achievement(
    id: 'checklist_5',
    icon: Icons.checklist_rounded,
    target: 5,
    value: (s) => s.maxSubtasksOnDoneTask,
    title: (l) => l.achievementChecklist5Title,
    description: (l) => l.achievementChecklist5Description,
  ),
];

List<AchievementProgress> progressOf(CompletionStats stats) => [
  for (final a in achievementCatalog) AchievementProgress(a, a.value(stats)),
];
