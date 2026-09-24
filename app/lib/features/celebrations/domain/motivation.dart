/// Choosing what to say when a task is ticked off.
///
/// Pure, so every rule is a unit test; the celebration controller gathers
/// the context and the overlay turns the choice into words.
library;

import 'dart:math';

import 'package:meta/meta.dart';

enum MotivationKind {
  /// Today just became empty.
  dayCleared,

  /// Exactly one Today task is left open.
  lastOne,

  /// This tick crossed half of Today.
  halfway,

  /// First completion today, continuing a streak of two days or more.
  streakDay,

  /// First completion today, no streak.
  firstOfDay,

  /// The task was due before today.
  overdue,

  /// "{done} of {total} done today".
  progress,

  /// Anything else.
  generic,
}

/// How many variants each kind has. The strings in `motivation_text.dart`
/// must provide exactly these.
const Map<MotivationKind, int> motivationVariants = {
  MotivationKind.dayCleared: 4,
  MotivationKind.lastOne: 3,
  MotivationKind.halfway: 3,
  MotivationKind.streakDay: 3,
  MotivationKind.firstOfDay: 4,
  MotivationKind.overdue: 3,
  MotivationKind.progress: 2,
  MotivationKind.generic: 12,
};

/// What is known about a completion when its message is chosen. Counts
/// already include the task just ticked off.
@immutable
class MotivationContext {
  const MotivationContext({
    required this.todayDone,
    required this.todayTotal,
    required this.wasInToday,
    required this.firstToday,
    required this.streak,
    required this.wasOverdue,
    required this.cleared,
  });

  /// Today tasks completed today.
  final int todayDone;

  /// [todayDone] plus Today tasks still open.
  final int todayTotal;

  /// The ticked task was one Today showed.
  final bool wasInToday;

  /// No other task was completed earlier today.
  final bool firstToday;

  /// Consecutive days with a completion, including today.
  final int streak;

  /// The task was due before the start of today.
  final bool wasOverdue;

  /// Nothing Today shows is open any more.
  final bool cleared;

  int get todayLeft => todayTotal - todayDone;
}

@immutable
class Motivation {
  const Motivation(this.kind, this.variant);

  final MotivationKind kind;

  /// Index into that kind's variants.
  final int variant;

  @override
  bool operator ==(Object other) =>
      other is Motivation && other.kind == kind && other.variant == variant;

  @override
  int get hashCode => Object.hash(kind, variant);

  @override
  String toString() => 'Motivation($kind, $variant)';
}

/// How many recent messages a new one must differ from.
const motivationMemory = 5;

/// Picks the message for a completion; the most specific situation wins.
///
/// [recent] holds the messages shown so far, newest last; a variant among
/// the last [motivationMemory] is skipped while another is left. [random]
/// is injected so tests are deterministic.
Motivation pickMotivation(
  MotivationContext c, {
  required List<Motivation> recent,
  required Random random,
}) {
  final kind = _kindFor(c, random);
  final count = motivationVariants[kind]!;
  final lately = recent.length > motivationMemory
      ? recent.sublist(recent.length - motivationMemory)
      : recent;
  final fresh = [
    for (var v = 0; v < count; v++)
      if (!lately.contains(Motivation(kind, v))) v,
  ];
  final pool = fresh.isEmpty ? [for (var v = 0; v < count; v++) v] : fresh;
  return Motivation(kind, pool[random.nextInt(pool.length)]);
}

MotivationKind _kindFor(MotivationContext c, Random random) {
  if (c.cleared) return MotivationKind.dayCleared;
  if (c.wasInToday && c.todayLeft == 1) return MotivationKind.lastOne;
  // Crossed by this tick; a day of two or three tasks goes straight from
  // the first to "one to go", which says the same thing better.
  if (c.wasInToday &&
      c.todayTotal >= 4 &&
      c.todayDone * 2 >= c.todayTotal &&
      (c.todayDone - 1) * 2 < c.todayTotal) {
    return MotivationKind.halfway;
  }
  if (c.firstToday) {
    return c.streak >= 2 ? MotivationKind.streakDay : MotivationKind.firstOfDay;
  }
  if (c.wasOverdue) return MotivationKind.overdue;
  // A count now and then says how the day is going without every line
  // being a number.
  if (c.wasInToday && c.todayTotal >= 2 && random.nextInt(3) == 0) {
    return MotivationKind.progress;
  }
  return MotivationKind.generic;
}
