import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/core/theme/app_style.dart';
import 'package:nemo/screens/style_adaptation.dart';

/// A page that moves as its style moves: in the Material style, as Android
/// does -- the theme's transitions, predictive back on Android 14 and
/// later -- and elsewhere nemo's fade, a Mac's crossfade or iOS's slide.
/// A plain swap under reduced motion.
Page<void> fadeThroughPage({
  required Widget child,
  required GoRouterState state,
}) => _StylePage(key: state.pageKey, name: state.name, child: child);

class _StylePage extends Page<void> {
  const _StylePage({required this.child, super.key, super.name});

  final Widget child;

  @override
  Route<void> createRoute(BuildContext context) => _StyleRoute(this);
}

/// A route with Material's transitions -- which read the theme, and follow
/// the back gesture where the theme's builder does -- for the Material
/// style, and each other style's own.
class _StyleRoute extends PageRoute<void> with MaterialRouteTransitionMixin {
  _StyleRoute(_StylePage page) : super(settings: page);

  _StylePage get _page => settings as _StylePage;

  bool get _material =>
      navigator?.context.mounted == true &&
      navigator!.context.appStyle == AppStyle.material;

  @override
  Widget buildContent(BuildContext context) => _page.child;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration =>
      _material ? super.transitionDuration : const Duration(milliseconds: 220);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (context.appStyle == AppStyle.material) {
      return super.buildTransitions(
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }
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
  }
}
