import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/features/achievements/data/achievements_repository.dart';
import 'package:nemo/features/achievements/domain/achievement.dart';
import 'package:nemo/features/achievements/ui/achievements_providers.dart';
import 'package:nemo/features/celebrations/domain/motivation.dart';
import 'package:nemo/features/settings/ui/settings_controller.dart';
import 'package:nemo/utils/dates.dart';
import 'package:nemo_core/nemo_core.dart';

/// What a completion earned; one per completion, the biggest that applies.
sealed class CelebrationEvent {
  const CelebrationEvent();
}

/// What to say about a completion, with what it was said about.
class CelebrationCheer {
  const CelebrationCheer(this.motivation, this.context);

  final Motivation motivation;
  final MotivationContext context;
}

/// An ordinary completion.
class TickCelebration extends CelebrationEvent {
  const TickCelebration({this.cheer, this.showPill = true});

  /// Null when choosing a message failed.
  final CelebrationCheer? cheer;

  /// False when the caller shows [cheer] itself (the swipe's snackbar).
  final bool showPill;
}

/// The last open task Today showed is done.
class DayClearedCelebration extends CelebrationEvent {
  const DayClearedCelebration({this.cheer, this.showPill = true});

  /// Null when choosing a message failed.
  final CelebrationCheer? cheer;

  /// False when the caller shows [cheer] itself (the swipe's snackbar).
  final bool showPill;
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
    Random? random,
    // The field is private and `now` is the public name callers use; an
    // initializing formal would have to share the field's (private) name.
    // ignore: prefer_initializing_formals
  }) : _now = now,
       _random = random ?? Random();

  final AchievementsRepository _repo;
  final DateTime Function() _now;
  final bool Function() celebrate;
  final bool Function() showAchievements;
  final Random _random;

  /// The messages shown last, oldest first, so the next one can differ.
  final _recent = <Motivation>[];
  final _events = StreamController<CelebrationEvent>.broadcast();

  Stream<CelebrationEvent> get events => _events.stream;

  Future<void> _turn = Future<void>.value();

  /// Runs [step] after every step already asked for, so a completion and a
  /// backfill never interleave. The chain survives a step that throws; the
  /// caller of that step still sees the error.
  Future<void> _inTurn(Future<void> Function() step) {
    final next = _turn.then((_) => step());
    _turn = next.then<void>((_) {}, onError: (Object _) {});
    return next;
  }

  /// After [task] was ticked off by a tap. [write] -- the tap's own write --
  /// runs in the same turn as the check, so a backfill asked for while it
  /// runs (a sync finishing) cannot record this tap's unlock first and
  /// swallow its banner. A failing [write] throws to the caller; a
  /// celebration going wrong never does.
  ///
  /// Returns the event this completion emitted, null when none; with
  /// [showPill] false the caller shows the message itself.
  Future<CelebrationEvent?> onCompleted(
    Task task, {
    Future<void> Function()? write,
    bool showPill = true,
  }) {
    // Captured inside the step rather than read from the chain, whose
    // shared tail swallows errors and carries no value.
    CelebrationEvent? emitted;
    return _inTurn(() async {
      if (write != null) await write();
      emitted = await _celebrate(task, showPill: showPill);
    }).then((_) => emitted);
  }

  Future<CelebrationEvent?> _celebrate(
    Task task, {
    required bool showPill,
  }) async {
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
        event = DayClearedCelebration(
          cheer: await _cheer(task, cleared: true, wasInToday: wasInToday),
          showPill: showPill,
        );
      } else {
        event = TickCelebration(
          cheer: await _cheer(task, cleared: false, wasInToday: wasInToday),
          showPill: showPill,
        );
      }
      if (event != null && !_events.isClosed) _events.add(event);
      return event;
    } on Object catch (error, stack) {
      debugPrint('Celebration failed: $error\n$stack');
      return null;
    }
  }

  /// Picks what to say; null if gathering the context fails, so the tick
  /// still gets its bounce without words.
  Future<CelebrationCheer?> _cheer(
    Task task, {
    required bool cleared,
    required bool wasInToday,
  }) async {
    try {
      final counts = await _repo.todayCounts();
      final context = MotivationContext(
        todayDone: counts.done,
        todayTotal: counts.done + counts.open,
        wasInToday: wasInToday,
        firstToday: await _repo.doneTodayCount() == 1,
        streak: (await _repo.stats()).currentStreak,
        // As the Today screen's Overdue section has it: a time already
        // passed today counts, not only an earlier day.
        wasOverdue: isOverdue(
          dueAt: task.dueAt,
          hasTime: task.dueHasTime,
          now: _now(),
        ),
        cleared: cleared,
      );
      final motivation = pickMotivation(
        context,
        recent: _recent,
        random: _random,
      );
      _recent.add(motivation);
      if (_recent.length > motivationMemory) _recent.removeAt(0);
      return CelebrationCheer(motivation, context);
    } on Object catch (error, stack) {
      debugPrint('Choosing a message failed: $error\n$stack');
      return null;
    }
  }

  /// Records everything already reached as celebrated, without a sound.
  ///
  /// Run at start and after every sync: nothing reached by then was a tap
  /// on this device, because a tap is celebrated in the turn it happens.
  Future<void> backfill() => _inTurn(() async {
    try {
      await _repo.markSeen((await _reached()).map((a) => a.id));
    } on Object catch (error, stack) {
      debugPrint('Achievement backfill failed: $error\n$stack');
    }
  });

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
