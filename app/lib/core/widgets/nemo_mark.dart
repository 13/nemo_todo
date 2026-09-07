import 'package:flutter/material.dart';

/// nemo's mark: a lowercase "n" whose right leg flicks up into a check.
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
  static const _strokeWidth = 48.0;

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / _canvas;
    canvas
      ..save()
      ..scale(scale);
    // M121 356 V236 A80 80 0 0 1 281 236 V322 L391 186
    final path = Path()
      ..moveTo(121, 356)
      ..lineTo(121, 236)
      ..arcToPoint(const Offset(281, 236), radius: const Radius.circular(80))
      ..lineTo(281, 322)
      ..lineTo(391, 186);
    canvas
      ..drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = _strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_NemoMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}
