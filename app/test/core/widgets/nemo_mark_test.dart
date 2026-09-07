import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/theme/app_theme.dart';
import 'package:nemo/core/widgets/nemo_mark.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: Center(child: child)),
    ),
  );

  testWidgets('the mark takes the size it is given', (tester) async {
    await pump(tester, const NemoMark(size: 48));
    expect(tester.getSize(find.byType(NemoMark)), const Size(48, 48));
  });

  testWidgets('the mark defaults to the primary colour and accepts another', (
    tester,
  ) async {
    await pump(tester, const NemoMark());
    expect(tester.getSize(find.byType(NemoMark)), const Size(24, 24));

    await pump(tester, const NemoMark(color: Colors.orange));
    final painter = tester
        .widget<CustomPaint>(
          find.descendant(
            of: find.byType(NemoMark),
            matching: find.byType(CustomPaint),
          ),
        )
        .painter!;
    // A different colour has to repaint, or the mark would keep the old one.
    expect(painter.shouldRepaint(painter), isFalse);
  });

  testWidgets('the tile centres the mark and rounds its corners', (
    tester,
  ) async {
    await pump(tester, const NemoLogoTile(size: 80));
    expect(tester.getSize(find.byType(NemoLogoTile)).width, 80);
    // The mark keeps its breathing room inside the tile.
    expect(tester.getSize(find.byType(NemoMark)).width, closeTo(52.8, 0.01));
    final box = tester.widget<Container>(
      find.descendant(
        of: find.byType(NemoLogoTile),
        matching: find.byType(Container),
      ),
    );
    final decoration = box.decoration! as BoxDecoration;
    expect(decoration.gradient, isA<LinearGradient>());
    expect(decoration.borderRadius, BorderRadius.circular(80 * 0.28));
  });
}
