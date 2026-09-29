import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nemo/core/theme/app_style.dart';
import 'package:nemo/core/theme/nemo_colors.dart';
import 'package:nemo/core/theme/surface_tint.dart';

/// [AppStyle.nemo]: Material 3 seeded from nemo's deep ocean teal.
abstract final class NemoTheme {
  static const seed = Color(0xFF0E7C86);

  static ThemeData light({
    Color? accent,
    SurfaceTint tint = SurfaceTint.subtle,
  }) {
    Color t(Color c) => tinted(c, tint, accent: accent);
    final base = _tintedScheme(
      ColorScheme.fromSeed(seedColor: seed).copyWith(
        primary: seed,
        surface: Colors.white,
        onSurface: const Color(0xFF16211F),
        onSurfaceVariant: const Color(0xFF45524F),
        outlineVariant: const Color(0xFFD9E3E1),
        surfaceContainerHighest: const Color(0xFFECF3F2),
      ),
      t,
    );
    final scheme = accented(base, accent);
    return _base(
      scheme,
      _withSelection(_tintedColors(NemoColors.light, t), scheme, accent),
    ).copyWith(scaffoldBackgroundColor: t(const Color(0xFFF5F8F8)));
  }

  static ThemeData dark({
    Color? accent,
    SurfaceTint tint = SurfaceTint.subtle,
  }) {
    Color t(Color c) => tinted(c, tint, accent: accent);
    final base = _tintedScheme(
      ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.dark,
      ).copyWith(
        primary: const Color(0xFF5BC0C9),
        onPrimary: const Color(0xFF00363B),
        surface: const Color(0xFF151F1F),
        onSurface: const Color(0xFFE3ECEB),
        onSurfaceVariant: const Color(0xFFA7B8B6),
        outlineVariant: const Color(0xFF2A3837),
        surfaceContainerHighest: const Color(0xFF1D2A29),
      ),
      t,
    );
    final scheme = accented(base, accent);
    return _base(
      scheme,
      _withSelection(_tintedColors(NemoColors.dark, t), scheme, accent),
    ).copyWith(scaffoldBackgroundColor: t(const Color(0xFF0E1616)));
  }

  /// [scheme]'s grounds, and the text and hairlines on them, through [t];
  /// its accent roles as they were.
  static ColorScheme _tintedScheme(
    ColorScheme scheme,
    Color Function(Color) t,
  ) => scheme.copyWith(
    surface: t(scheme.surface),
    onSurface: t(scheme.onSurface),
    onSurfaceVariant: t(scheme.onSurfaceVariant),
    outlineVariant: t(scheme.outlineVariant),
    surfaceDim: t(scheme.surfaceDim),
    surfaceBright: t(scheme.surfaceBright),
    surfaceContainerLowest: t(scheme.surfaceContainerLowest),
    surfaceContainerLow: t(scheme.surfaceContainerLow),
    surfaceContainer: t(scheme.surfaceContainer),
    surfaceContainerHigh: t(scheme.surfaceContainerHigh),
    surfaceContainerHighest: t(scheme.surfaceContainerHighest),
  );

  /// [nemo]'s sidebar and hairlines through [t].
  static NemoColors _tintedColors(NemoColors nemo, Color Function(Color) t) {
    final sidebar = t(nemo.sidebar);
    final separator = t(nemo.separator);
    return sidebar == nemo.sidebar && separator == nemo.separator
        ? nemo
        : nemo.copyWith(sidebar: sidebar, separator: separator);
  }

  /// nemo marks a selection in its accent, so a chosen accent takes it on.
  static NemoColors _withSelection(
    NemoColors nemo,
    ColorScheme scheme,
    Color? accent,
  ) => accent == null
      ? nemo
      : nemo.copyWith(selection: scheme.primary.withValues(alpha: 0.14));

  static ThemeData _base(ColorScheme scheme, NemoColors nemo) {
    final textTheme = manropeTextTheme(scheme);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      extensions: [nemo, const AppStyleTheme(AppStyle.nemo)],
      appBarTheme: AppBarTheme(
        centerTitle: false,
        systemOverlayStyle: systemBarsFor(scheme),
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        isDense: true,
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        backgroundColor: scheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        labelType: NavigationRailLabelType.all,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      listTileTheme: const ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      splashFactory: InkSparkle.splashFactory,
    );
  }
}

/// Material 2021 type in Manrope, coloured for [scheme]; every style's.
TextTheme manropeTextTheme(ColorScheme scheme) =>
    Typography.material2021(colorScheme: scheme).englishLike.apply(
      fontFamily: 'Manrope',
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

/// Android's status and navigation bars over [scheme]'s surfaces: see-
/// through, with icons that contrast with what shows through them.
///
/// Every style's app bar is transparent, and left to itself an app bar
/// reads that as black and asks for white icons -- invisible on a light
/// window.
SystemUiOverlayStyle systemBarsFor(ColorScheme scheme) {
  final light = scheme.brightness == Brightness.light;
  final icons = light ? Brightness.dark : Brightness.light;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: icons,
    // iOS names the bar's background, not its icons.
    statusBarBrightness: scheme.brightness,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: icons,
    systemNavigationBarContrastEnforced: false,
  );
}

/// [scheme] with its accent roles -- primary and its container -- taken
/// from [accent], or as it was where there is none.
///
/// Derived through Material's colour system rather than pasted in, so
/// whatever the accent, text on it and it on the window keep their
/// contrast: a light accent comes out deeper in light mode, lighter in dark.
ColorScheme accented(ColorScheme scheme, Color? accent) {
  if (accent == null) return scheme;
  final from = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: scheme.brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  );
  return scheme.copyWith(
    primary: from.primary,
    onPrimary: from.onPrimary,
    primaryContainer: from.primaryContainer,
    onPrimaryContainer: from.onPrimaryContainer,
    inversePrimary: from.inversePrimary,
    surfaceTint: scheme.surfaceTint == Colors.transparent
        ? Colors.transparent
        : from.primary,
  );
}
