import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/widgets/task_tile.dart';

/// A bare [DoneCheck], recording what it reports.
Future<List<bool>> pumpCheck(
  WidgetTester tester, {
  required bool done,
  required bool celebrate,
}) async {
  final changes = <bool>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: DoneCheck(
            done: done,
            celebrate: celebrate,
            onChanged: changes.add,
          ),
        ),
      ),
    ),
  );
  return changes;
}

double scaleOf(WidgetTester tester) => tester
    .widget<ScaleTransition>(
      find.descendant(
        of: find.byType(DoneCheck),
        matching: find.byType(ScaleTransition),
      ),
    )
    .scale
    .value;

void main() {
  testWidgets('ticking with celebrations bounces and settles', (tester) async {
    final changes = await pumpCheck(tester, done: false, celebrate: true);

    await tester.tap(find.byType(DoneCheck));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(scaleOf(tester), greaterThan(1));

    await tester.pump(const Duration(milliseconds: 300));
    expect(scaleOf(tester), 1);
    expect(changes, [true]);
  });

  testWidgets('reduced motion ticks without the bounce', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final changes = await pumpCheck(tester, done: false, celebrate: true);

    await tester.tap(find.byType(DoneCheck));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(scaleOf(tester), 1);
    expect(changes, [true]);
  });

  testWidgets('ticking without celebrations does not bounce', (tester) async {
    final changes = await pumpCheck(tester, done: false, celebrate: false);

    await tester.tap(find.byType(DoneCheck));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(scaleOf(tester), 1);
    expect(changes, [true]);
  });

  testWidgets('unticking a done task never bounces', (tester) async {
    final changes = await pumpCheck(tester, done: true, celebrate: true);

    await tester.tap(find.byType(DoneCheck));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(scaleOf(tester), 1);
    expect(changes, [false]);
  });
}
