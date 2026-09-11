import 'package:flutter/material.dart';

/// nemo's mark: a clownfish, banded the way the fish the app is named
/// after is banded.
///
/// One colour, and the bands are holes rather than a second colour -- so
/// whatever is behind the mark shows through them. That is what lets the
/// same artwork be the teal mark on a page, the white fish on the launcher
/// tile, and the silhouette Android draws in the status bar from nothing
/// but an alpha channel.
///
/// Drawn rather than loaded from an asset so it stays crisp at any size and
/// takes its colour from the theme. The geometry matches
/// `assets/logo/nemo-mark.svg`; change both together.
class NemoMark extends StatelessWidget {
  const NemoMark({this.size = 24, this.color, super.key});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _NemoMarkPainter(color ?? Theme.of(context).colorScheme.primary),
    ),
  );
}

/// The mark inside nemo's rounded tile, as the launcher icon shows it.
class NemoLogoTile extends StatelessWidget {
  const NemoLogoTile({this.size = 40, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF13949F), Color(0xFF0A5C66)],
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Center(
        child: NemoMark(size: size * 0.66, color: scheme.onPrimary),
      ),
    );
  }
}

class _NemoMarkPainter extends CustomPainter {
  const _NemoMarkPainter(this.color);

  /// The master artwork is drawn on a 512 canvas.
  static const _canvas = 512.0;

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / _canvas;
    canvas
      ..save()
      ..scale(scale);
    // Body and fins, then the three bands and the eye. They are holes, so
    // the whole thing is one path wound even-odd rather than a shape with
    // lighter shapes laid over it.
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..moveTo(73, 256)
      ..cubicTo(79, 196, 133, 156, 195, 144)
      ..cubicTo(203, 118, 215, 98, 233, 84)
      ..cubicTo(245, 118, 251, 144, 253, 158)
      ..cubicTo(287, 168, 317, 186, 337, 210)
      ..lineTo(439, 148)
      ..cubicTo(415, 188, 405, 224, 403, 256)
      ..cubicTo(405, 288, 415, 324, 439, 364)
      ..lineTo(337, 302)
      ..cubicTo(317, 326, 287, 344, 253, 354)
      ..cubicTo(251, 368, 245, 394, 233, 428)
      ..cubicTo(215, 414, 203, 394, 195, 368)
      ..cubicTo(133, 356, 79, 316, 73, 256)
      ..close()
      ..moveTo(181, 184)
      ..cubicTo(191, 180, 203, 176, 215, 174)
      ..lineTo(199, 338)
      ..cubicTo(187, 336, 175, 332, 165, 328)
      ..close()
      ..moveTo(259, 174)
      ..cubicTo(273, 178, 285, 184, 295, 192)
      ..lineTo(277, 320)
      ..cubicTo(267, 328, 255, 334, 243, 338)
      ..close()
      ..moveTo(317, 204)
      ..cubicTo(325, 210, 333, 218, 339, 226)
      ..lineTo(325, 286)
      ..cubicTo(319, 294, 311, 302, 303, 308)
      ..close()
      ..moveTo(115, 234)
      ..arcToPoint(
        const Offset(159, 234),
        radius: const Radius.circular(22),
        largeArc: true,
        clockwise: false,
      )
      ..arcToPoint(
        const Offset(115, 234),
        radius: const Radius.circular(22),
        largeArc: true,
        clockwise: false,
      )
      ..close();
    canvas
      ..drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_NemoMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}
