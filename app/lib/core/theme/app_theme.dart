import 'package:flutter/material.dart';
import 'package:nemo/core/theme/app_style.dart';
import 'package:nemo/core/theme/macos_theme.dart';
import 'package:nemo/core/theme/material_theme.dart';
import 'package:nemo/core/theme/nemo_colors.dart';
import 'package:nemo/core/theme/nemo_theme.dart';
import 'package:nemo/core/theme/surface_tint.dart';

/// The app's themes, one pair per [AppStyle].
abstract final class AppTheme {
  /// nemo's brand teal: the logo, the launcher icon and the nemo style.
  static const Color seed = NemoTheme.seed;

  /// [style] in [brightness]. [wallpaper] colours the Material style where
  /// the device has offered its own; [accent], a slot of [accents], replaces
  /// the style's own accent in any style; [tint] is how much of it the nemo
  /// style's backgrounds take on, and the other styles ignore it.
  static ThemeData build(
    AppStyle style,
    Brightness brightness, {
    WallpaperSchemes? wallpaper,
    int? accent,
    SurfaceTint tint = SurfaceTint.subtle,
  }) {
    final chosen = accent == null
        ? null
        : accents(style)[accent % accents(style).length];
    return switch ((style, brightness)) {
      (AppStyle.nemo, Brightness.light) => NemoTheme.light(
        accent: chosen,
        tint: tint,
      ),
      (AppStyle.nemo, Brightness.dark) => NemoTheme.dark(
        accent: chosen,
        tint: tint,
      ),
      (AppStyle.macos, Brightness.light) => MacosTheme.light(accent: chosen),
      (AppStyle.macos, Brightness.dark) => MacosTheme.dark(accent: chosen),
      (AppStyle.material, _) => Material3Theme.build(
        brightness,
        wallpaper: brightness == Brightness.light
            ? wallpaper?.light
            : wallpaper?.dark,
        accent: chosen,
      ),
    };
  }

  /// The accents Settings offers for [style]: its list colours, in the
  /// palette's slots (teal, blue, purple, pink, red, orange, green, grey).
  static List<Color> accents(AppStyle style) => switch (style) {
    AppStyle.macos => MacosTheme.lightColors.listPalette,
    AppStyle.nemo || AppStyle.material => NemoColors.light.listPalette,
  };

  /// The nemo style's light theme.
  static ThemeData light() => build(AppStyle.nemo, Brightness.light);

  /// The nemo style's dark theme.
  static ThemeData dark() => build(AppStyle.nemo, Brightness.dark);
}
