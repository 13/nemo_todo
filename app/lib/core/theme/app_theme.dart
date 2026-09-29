import 'package:flutter/material.dart';
import 'package:nemo/core/theme/app_style.dart';
import 'package:nemo/core/theme/nemo_theme.dart';

/// The app's themes, one pair per [AppStyle].
abstract final class AppTheme {
  /// nemo's brand teal: the logo, the launcher icon and the nemo style.
  static const Color seed = NemoTheme.seed;

  static ThemeData build(AppStyle style, Brightness brightness) =>
      switch ((style, brightness)) {
        (_, Brightness.light) => NemoTheme.light(),
        (_, Brightness.dark) => NemoTheme.dark(),
      };

  /// The nemo style's light theme.
  static ThemeData light() => build(AppStyle.nemo, Brightness.light);

  /// The nemo style's dark theme.
  static ThemeData dark() => build(AppStyle.nemo, Brightness.dark);
}
