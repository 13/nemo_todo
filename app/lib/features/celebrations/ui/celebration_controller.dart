import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/features/achievements/data/achievements_repository.dart';
import 'package:nemo/features/achievements/domain/achievement.dart';
import 'package:nemo/features/achievements/ui/achievements_providers.dart';
import 'package:nemo/features/settings/ui/settings_controller.dart';
import 'package:nemo/utils/dates.dart';
import 'package:nemo_core/nemo_core.dart';

/// What a completion earned; one per completion, the biggest that applies.
sealed class CelebrationEvent {
  const CelebrationEvent();
}

/// An ordinary completion.
class TickCelebration extends CelebrationEvent {
  const TickCelebration();
}

/// The last open task Today showed is done.
class DayClearedCelebration extends CelebrationEvent {
  const DayClearedCelebration();
}

class AchievementsUnlocked extends CelebrationEvent {
  const AchievementsUnlocked(this.achievements);

  final List<Achievement> achievements;
}

/// Decides what a completion made on this device earns.
///
/// Only a person's tap reaches [onCompleted]; rows written by sync never
/// do, and what they unlock is recorded quietly by [backfill] so a later
/// tap does not take the credit.
class CelebrationController {
  CelebrationController(
    this._repo, {
    required DateTime Function() now,
    required this.celebrate,
    required this.showAchievements,
    // The field is private and `now` is the public name callers use; an
    // initializing formal would have to share the field's (private) name.
    // ignore: prefer_initializing_formals
  }) : _now = now;

  final AchievementsRepository _repo;
  final DateTime Function() _now;
  final bool Function() celebrate;
  final bool Function() showAchievements;
  final _events = StreamController<CelebrationEvent>.broadcast();

  Stream<CelebrationEvent> get events => _events.stream;

  /// After [task] was ticked off by a tap. Never throws: the task is
  /// already done, and a celebration going wrong must not say otherwise.
  Future<void> onCompleted(Task task) async {
    try {
      final dueAt = task.dueAt;
      final wasInToday = dueAt != null && dueAt < dayStartMsFrom(_now(), 1);
      final cleared = wasInToday && await _repo.todayIsClear();
      if (cleared) await _repo.recordClearedDay();

      // Unset means the quiet first check has not happened: record now,
      // celebrate nothing, rather than celebrate a whole history at once.
      final seen = await _repo.seen();
      final reached = await _reached();
      final fresh = seen == null
          ? const <Achievement>[]
          : [
              for (final a in reached)
                if (!seen.contains(a.id)) a,
            ];
      await _repo.markSeen(reached.map((a) => a.id));

      final CelebrationEvent? event;
      if (fresh.isNotEmpty && showAchievements()) {
        event = AchievementsUnlocked(fresh);
      } else if (!celebrate()) {
        event = null;
      } else if (cleared) {
        event = const DayClearedCelebration();
      } else {
        event = const TickCelebration();
      }
      if (event != null && !_events.isClosed) _events.add(event);
    } on Object catch (error, stack) {
      debugPrint('Celebration failed: $error\n$stack');
    }
  }

  /// Records everything already reached as celebrated, without a sound.
  ///
  /// Run at start and after every sync: nothing reached by then was a tap
  /// on this device, because a tap is celebrated the moment it happens.
  Future<void> backfill() async {
    try {
      await _repo.markSeen((await _reached()).map((a) => a.id));
    } on Object catch (error, stack) {
      debugPrint('Achievement backfill failed: $error\n$stack');
    }
  }

  Future<List<Achievement>> _reached() async => [
    for (final p in await _repo.progress())
      if (p.unlocked) p.achievement,
  ];

  void dispose() => unawaited(_events.close());
}

final celebrationControllerProvider = Provider<CelebrationController>((ref) {
  final controller = CelebrationController(
    ref.watch(achievementsRepositoryProvider),
    now: ref.watch(nowProvider),
    celebrate: () => ref.read(celebrationsEnabledProvider),
    showAchievements: () => ref.read(achievementsEnabledProvider),
  );
  ref.onDispose(controller.dispose);
  return controller;
});
