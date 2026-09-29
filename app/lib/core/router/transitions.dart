import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/core/theme/app_style.dart';
import 'package:nemo/screens/style_adaptation.dart';

/// Fade + slight scale for page navigation; plain swap under reduced motion.
Page<void> fadeThroughPage({
  required Widget child,
  required GoRouterState state,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.disableAnimationsOf(context)) return child;
      if (context.appStyle == AppStyle.macos) {
        // A phone slides pages in from the side, as iOS does; a Mac window
        // just shows the next thing, with the briefest of crossfades.
        if (StyleAdaptation.isPhone(context)) {
          return CupertinoPageTransition(
            primaryRouteAnimation: animation,
            secondaryRouteAnimation: secondaryAnimation,
            linearTransition: false,
            child: child,
          );
        }
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      }
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}
