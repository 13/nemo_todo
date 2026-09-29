import 'package:flutter/material.dart';

/// The look of the app, chosen in Settings independently of light and
/// dark: nemo's own, one modelled on macOS, or plain Material 3.
enum AppStyle {
  /// nemo's deep ocean teal; the default, and what the app has always been.
  nemo,

  /// Graphite neutrals, system blue, hairlines and a floating sidebar.
  macos,

  /// Material 3 as Android draws it, in the wallpaper's colours where the
  /// device offers them.
  material,
}

/// Which [AppStyle] a theme was built for, for the few widgets whose
/// layout rather than colour differs between styles.
@immutable
class AppStyleTheme extends ThemeExtension<AppStyleTheme> {
  const AppStyleTheme(this.style);

  final AppStyle style;

  @override
  AppStyleTheme copyWith({AppStyle? style}) =>
      AppStyleTheme(style ?? this.style);

  @override
  AppStyleTheme lerp(AppStyleTheme? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

extension AppStyleContext on BuildContext {
  AppStyle get appStyle =>
      Theme.of(this).extension<AppStyleTheme>()?.style ?? AppStyle.nemo;

  /// The pointer over something to click: an arrow on a Mac, where only
  /// links show a hand; null keeps a widget's own (the hand elsewhere).
  MouseCursor? get clickCursor =>
      appStyle == AppStyle.macos ? SystemMouseCursors.basic : null;
}

/// Scrolling as Apple's platforms do it: past the end with a bounce.
class AppleScrollBehavior extends MaterialScrollBehavior {
  const AppleScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: RangeMaintainingScrollPhysics());
}
