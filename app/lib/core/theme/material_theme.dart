import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nemo/core/theme/app_style.dart';
import 'package:nemo/core/theme/nemo_colors.dart';
import 'package:nemo/core/theme/nemo_theme.dart';

/// Colour schemes from the device's wallpaper, light and dark.
typedef WallpaperSchemes = ({ColorScheme light, ColorScheme dark});

/// The wallpaper's colours where Android offers them (12 and later), read
/// once before the first frame so the app does not open in teal and then
/// change colour; null anywhere else, or if the device will not say.
Future<WallpaperSchemes?> loadWallpaperSchemes() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
  try {
    final palette = await DynamicColorPlugin.getCorePalette();
    if (palette == null) return null;
    return (
      light: palette.toColorScheme(),
      dark: palette.toColorScheme(brightness: Brightness.dark),
    );
  } on Object {
    return null;
  }
}

/// [AppStyle.material]: Material 3 as Android draws it -- the wallpaper's
/// colours where there are some, nemo's teal as the seed where not, and
/// Material's own shapes, ripples and pill indicators throughout.
abstract final class Material3Theme {
  static ThemeData build(Brightness brightness, {ColorScheme? wallpaper}) {
    final scheme =
        wallpaper ??
        ColorScheme.fromSeed(seedColor: NemoTheme.seed, brightness: brightness);
    final base = brightness == Brightness.light
        ? NemoColors.light
        : NemoColors.dark;
    // Lists and priorities keep their hues, nudged towards the scheme's
    // so they sit with whatever colours the wallpaper chose, and deepened
    // or lightened where that leaves them too faint to see as an icon.
    Color fit(Color c) =>
        _legible(c.harmonizeWith(scheme.primary), scheme.surface);
    final nemo = base.copyWith(
      priorityLow: fit(base.priorityLow),
      priorityMedium: fit(base.priorityMedium),
      // High is a warning, and Material's colour for that is error.
      priorityHigh: scheme.error,
      overdue: scheme.error,
      listPalette: [for (final c in base.listPalette) fit(c)],
      sidebar: scheme.surfaceContainer,
      separator: scheme.outlineVariant,
      selection: scheme.secondaryContainer,
      tintedMetaText: false,
    );
    final textTheme = manropeTextTheme(scheme);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      extensions: [nemo, const AppStyleTheme(AppStyle.material)],
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(centerTitle: false),
      // The quick-add field reads as Material's search bar: a filled pill.
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
      ),
      cardTheme: const CardThemeData(margin: EdgeInsets.zero),
      bottomSheetTheme: const BottomSheetThemeData(showDragHandle: true),
      navigationBarTheme: const NavigationBarThemeData(
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        labelType: NavigationRailLabelType.all,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// [c], moved towards the far end of lightness from [background] just
  /// until the two are 3:1 apart, what an icon needs to be seen.
  static Color _legible(Color c, Color background) {
    final darken = background.computeLuminance() > 0.5;
    var hsl = HSLColor.fromColor(c);
    for (var i = 0; i < 40 && _contrast(hsl.toColor(), background) < 3; i++) {
      final l = hsl.lightness + (darken ? -0.01 : 0.01);
      hsl = hsl.withLightness(l.clamp(0, 1));
    }
    return hsl.toColor();
  }

  static double _contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    return ((la > lb ? la : lb) + 0.05) / ((la > lb ? lb : la) + 0.05);
  }
}
