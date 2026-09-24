import 'package:flutter/material.dart';

/// A short message after a completion: small, calm, out of the way.
///
/// Ignores pointers so it never takes the next tap, and is a live region
/// so a screen reader reads it out.
class MotivationPill extends StatelessWidget {
  const MotivationPill({
    required this.text,
    required this.visible,
    required this.animate,
    super.key,
  });

  final String text;
  final bool visible;

  /// False under reduced motion: the pill appears and goes without a fade.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return IgnorePointer(
      // Starts from nothing, so the pill fades in when it is first put on
      // screen; an AnimatedOpacity would begin at its target and skip that.
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: visible ? 1 : 0),
        duration: animate
            ? Duration(milliseconds: visible ? 150 : 200)
            : Duration.zero,
        builder: (context, opacity, child) =>
            Opacity(opacity: opacity, child: child),
        child: Semantics(
          liveRegion: true,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Material(
              color: scheme.inverseSurface,
              elevation: 3,
              shape: const StadiumBorder(),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: scheme.inversePrimary,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodyMedium?.copyWith(
                          color: scheme.onInverseSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
