import 'package:flutter/material.dart';
import 'package:nemo/core/theme/app_style.dart';
import 'package:nemo/core/theme/macos_theme.dart';
import 'package:nemo/core/theme/material_theme.dart';
import 'package:nemo/core/theme/nemo_theme.dart';

/// The app's themes, one pair per [AppStyle].
abstract final class AppTheme {
  /// nemo's brand teal: the logo, the launcher icon and the nemo style.
  static const Color seed = NemoTheme.seed;

  /// [style] in [brightness]. [wallpaper] colours the Material style where
  /// the device has offered its own; the other styles have fixed colours.
  static ThemeData build(
    AppStyle style,
    Brightness brightness, {
    WallpaperSchemes? wallpaper,
  }) => switch ((style, brightness)) {
    (AppStyle.nemo, Brightness.light) => NemoTheme.light(),
    (AppStyle.nemo, Brightness.dark) => NemoTheme.dark(),
    (AppStyle.macos, Brightness.light) => MacosTheme.light(),
    (AppStyle.macos, Brightness.dark) => MacosTheme.dark(),
    (AppStyle.material, _) => Material3Theme.build(
      brightness,
      wallpaper: brightness == Brightness.light
          ? wallpaper?.light
          : wallpaper?.dark,
    ),
  };

  /// The nemo style's light theme.
  static ThemeData light() => build(AppStyle.nemo, Brightness.light);

  /// The nemo style's dark theme.
  static ThemeData dark() => build(AppStyle.nemo, Brightness.dark);
}
