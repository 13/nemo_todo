import 'package:flutter/material.dart';

/// nemo's mark: a checkmark, cut out of a disc.
///
/// One colour, and the check is a hole rather than a second colour -- so
/// whatever is behind the mark shows through it. That is what lets the
/// same artwork be the teal mark in the app and on the web page's loading
/// screen, the white disc on the launcher tile, and the silhouette Android
/// draws in the status bar from nothing but an alpha channel.
///
/// Drawn rather than loaded from an asset so it stays crisp at any size and
/// takes its colour from the theme. The geometry matches
/// `assets/logo/nemo-mark.svg`; change both together.
class NemoMark extends StatelessWidget {
  const NemoMark({this.size = 24, this.color, super.key});

  final double size;
  final Color? color;

  // Art, always beside the app's name or in place of a picture: a screen
  // reader has nothing to say about it.
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _NemoMarkPainter(
          color ?? Theme.of(context).colorScheme.primary,
        ),
      ),
    ),
  );
}

/// The mark as the web page's loading screen draws it: inside a faint
/// ring, both centred, at the same sizes as `web/index.html` -- so when the
/// page fades its loading screen out over the app's first frame, this is
/// already there underneath, and nothing moves. Change both together.
///
/// The page's ring spins. This one stands still: it is on screen while the
/// app works out whether anyone is signed in, and a spinner that lingers
/// reads as a failure rather than as progress.
class NemoSplashMark extends StatelessWidget {
  const NemoSplashMark({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return SizedBox.square(
      dimension: 96,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: primary.withValues(alpha: 0.18), width: 3),
        ),
        // A 64 px disc, as on the page. The page's SVG is cropped to the
        // disc; the mark's canvas is 512 across with a disc of 400.
        child: const Center(child: NemoMark(size: 64 * 512 / 400)),
      ),
    );
  }
}

class _NemoMarkPainter extends CustomPainter {
  const _NemoMarkPainter(this.color);

  /// The master artwork is drawn on a 512 canvas.
  static const _canvas = 512.0;

  /// Half the width of the check's stroke, which is also the radius of its
  /// rounded ends and its outer corner.
  static const _stroke = Radius.circular(31.5);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / _canvas;
    canvas
      ..save()
      ..scale(scale);
    // The disc, then the outline of the check. The check is a hole, so the
    // whole thing is one path wound even-odd rather than a white check laid
    // over a teal disc.
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..moveTo(56, 256)
      ..arcToPoint(
        const Offset(456, 256),
        radius: const Radius.circular(200),
        largeArc: true,
        clockwise: false,
      )
      ..arcToPoint(
        const Offset(56, 256),
        radius: const Radius.circular(200),
        largeArc: true,
        clockwise: false,
      )
      ..close()
      ..moveTo(127.87, 265.42)
      ..lineTo(206.87, 343.42)
      ..arcToPoint(
        const Offset(251.10, 343.45),
        radius: _stroke,
        clockwise: false,
      )
      ..lineTo(381.10, 215.45)
      ..arcToPoint(
        const Offset(381.45, 170.90),
        radius: _stroke,
        clockwise: false,
      )
      ..arcToPoint(
        const Offset(336.90, 170.55),
        radius: _stroke,
        clockwise: false,
      )
      ..lineTo(229.03, 276.76)
      ..lineTo(172.13, 220.58)
      ..arcToPoint(
        const Offset(127.58, 220.87),
        radius: _stroke,
        clockwise: false,
      )
      ..arcToPoint(
        const Offset(127.87, 265.42),
        radius: _stroke,
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
