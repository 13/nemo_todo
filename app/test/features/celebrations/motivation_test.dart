import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/celebrations/domain/motivation.dart';

MotivationContext ctx({
  int done = 1,
  int total = 5,
  bool inToday = true,
  bool first = false,
  int streak = 1,
  bool overdue = false,
  bool cleared = false,
}) => MotivationContext(
  todayDone: done,
  todayTotal: total,
  wasInToday: inToday,
  firstToday: first,
  streak: streak,
  wasOverdue: overdue,
  cleared: cleared,
);

MotivationKind kindOf(MotivationContext c, {int seed = 1}) =>
    pickMotivation(c, recent: const [], random: Random(seed)).kind;

void main() {
  test('priority: cleared beats everything', () {
    expect(
      kindOf(
        ctx(done: 5, first: true, streak: 3, overdue: true, cleared: true),
      ),
      MotivationKind.dayCleared,
    );
  });

  test('one left', () {
    expect(kindOf(ctx(done: 4)), MotivationKind.lastOne);
    expect(kindOf(ctx(total: 2, first: true)), MotivationKind.lastOne);
  });

  test('halfway only on the tick that crosses it, and not on small days', () {
    expect(kindOf(ctx(done: 2, total: 4)), MotivationKind.halfway);
    expect(kindOf(ctx(done: 3, total: 6)), MotivationKind.halfway);
    expect(kindOf(ctx(done: 3)), MotivationKind.halfway);
    expect(kindOf(ctx(done: 4, total: 6)), isNot(MotivationKind.halfway));
    expect(kindOf(ctx(done: 2, total: 3)), MotivationKind.lastOne);
  });

  test('first of the day, with and without a streak', () {
    expect(
      kindOf(ctx(total: 6, first: true, streak: 4)),
      MotivationKind.streakDay,
    );
    expect(kindOf(ctx(total: 6, first: true)), MotivationKind.firstOfDay);
    expect(
      kindOf(ctx(done: 0, total: 0, inToday: false, first: true)),
      MotivationKind.firstOfDay,
    );
  });

  test('an overdue task gets its own line', () {
    expect(kindOf(ctx(total: 8, overdue: true)), MotivationKind.overdue);
  });

  test('ordinary ticks mix progress and generic, generic outside Today', () {
    final kinds = {for (var s = 0; s < 60; s++) kindOf(ctx(total: 8), seed: s)};
    expect(kinds, {MotivationKind.progress, MotivationKind.generic});
    for (var s = 0; s < 20; s++) {
      expect(
        kindOf(ctx(done: 0, total: 0, inToday: false), seed: s),
        MotivationKind.generic,
      );
    }
  });

  test('a variant among the last five is not repeated', () {
    final c = ctx(total: 0, inToday: false);
    final recent = <Motivation>[];
    for (var i = 0; i < 40; i++) {
      final m = pickMotivation(c, recent: recent, random: Random(i));
      expect(
        recent.skip(recent.length > 5 ? recent.length - 5 : 0),
        isNot(contains(m)),
      );
      recent.add(m);
    }
  });

  test('when every variant is recent, one is still picked', () {
    final c = ctx(done: 4); // lastOne has 3 variants
    final recent = [
      for (var v = 0; v < motivationVariants[MotivationKind.lastOne]!; v++)
        Motivation(MotivationKind.lastOne, v),
    ];
    final m = pickMotivation(c, recent: recent, random: Random(3));
    expect(m.kind, MotivationKind.lastOne);
    expect(m.variant, lessThan(motivationVariants[MotivationKind.lastOne]!));
  });

  test('every kind has variants', () {
    for (final k in MotivationKind.values) {
      expect(motivationVariants[k], greaterThan(0), reason: '$k');
    }
  });
}
