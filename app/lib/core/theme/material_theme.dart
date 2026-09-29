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
  /// A chosen [accent] seeds the scheme in place of the wallpaper.
  static ThemeData build(
    Brightness brightness, {
    ColorScheme? wallpaper,
    Color? accent,
  }) {
    final scheme = accent == null && wallpaper != null
        ? wallpaper
        : ColorScheme.fromSeed(
            seedColor: accent ?? NemoTheme.seed,
            brightness: brightness,
          );
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
    // Android's own type, Roboto: on Android the copy every device has,
    // which Flutter asks for by name; on the web, one bundled under a name
    // of its own so Android never loads it.
    const fontFamily = kIsWeb ? 'RobotoWeb' : null;
    // A step towards Material 3 Expressive, which Flutter does not have
    // yet: rounder surfaces, and buttons that square off a little while
    // pressed, from the theme alone so the real thing can replace it.
    const corner = 20.0;
    OutlinedBorder pressable(Set<WidgetState> s) => RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(
        s.contains(WidgetState.pressed) ? 12 : 40,
      ),
    );
    final morph = ButtonStyle(
      shape: WidgetStateProperty.resolveWith(pressable),
      animationDuration: const Duration(milliseconds: 150),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      extensions: [nemo, const AppStyleTheme(AppStyle.material)],
      splashFactory: InkSparkle.splashFactory,
      // Back as Android 14 draws it: the page shrinks to show where the
      // gesture leads, and lets go or springs back (see app.dart for the
      // routes that follow this).
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        systemOverlayStyle: systemBarsFor(scheme),
        backgroundColor: scheme.surface,
        scrolledUnderElevation: 3,
      ),
      // Fields are Material's search bar: a filled pill.
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
      ),
      // Filled, tonal cards: Material 3's own, with no outline.
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(corner),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        backgroundColor: scheme.surfaceContainerLow,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      filledButtonTheme: FilledButtonThemeData(style: morph),
      elevatedButtonTheme: ElevatedButtonThemeData(style: morph),
      outlinedButtonTheme: OutlinedButtonThemeData(style: morph),
      textButtonTheme: TextButtonThemeData(style: morph),
      // A switch shows a tick in its thumb when on, as Android's do.
      switchTheme: SwitchThemeData(
        thumbIcon: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? const Icon(Icons.check_rounded)
              : null,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
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
