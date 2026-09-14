import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  /// The colour of one pixel of [NemoMark] painted on the 512 master canvas,
  /// so the points below are the master artwork's own coordinates.
  Future<Color> pixelOfMark(WidgetTester tester, Offset at) async {
    tester.view.physicalSize = const Size(512, 512);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const boundary = GlobalObjectKey('mark');
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: boundary,
            child: NemoMark(size: 512, color: Color(0xFF0E7C86)),
          ),
        ),
      ),
    );
    final render = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(boundary),
    );
    final bytes = (await tester.runAsync(() async {
      final image = await render.toImage();
      return await image.toByteData();
    }))!;
    final i = (at.dy.toInt() * 512 + at.dx.toInt()) * 4;
    return Color.fromARGB(
      bytes.getUint8(i + 3),
      bytes.getUint8(i),
      bytes.getUint8(i + 1),
      bytes.getUint8(i + 2),
    );
  }

  testWidgets('the mark is a disc with the check cut out of it', (
    tester,
  ) async {
    // Inside the disc, clear of the check.
    final disc = await pixelOfMark(tester, const Offset(256, 440));
    expect(disc.a, closeTo(1, 0.01));
    expect(disc.toARGB32(), 0xFF0E7C86);

    // On the check, just above its elbow: a hole, so the background shows.
    final check = await pixelOfMark(tester, const Offset(229, 310));
    expect(check.a, 0);

    // Outside the disc altogether.
    final outside = await pixelOfMark(tester, const Offset(10, 10));
    expect(outside.a, 0);
  });

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
    expect(tester.getSize(find.byType(NemoMark)).width, closeTo(60.8, 0.01));
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
