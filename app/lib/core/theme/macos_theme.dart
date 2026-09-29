import 'package:flutter/material.dart';
import 'package:nemo/core/theme/app_style.dart';
import 'package:nemo/core/theme/nemo_colors.dart';
import 'package:nemo/core/theme/nemo_theme.dart';

/// [AppStyle.macos]: modelled on macOS 26 -- graphite neutrals with no
/// tint, system blue as the one accent, hairlines rather than outlines,
/// capsule controls, and highlights where Material would ripple.
///
/// Every role of the scheme is set here rather than derived from a seed,
/// since a seed tints each grey towards itself and macOS's greys are grey.
abstract final class MacosTheme {
  /// System blue as the light appearance can read it: `#007AFF` is 4.0:1
  /// on white, short of what body text needs; Apple's own web accent is
  /// the same blue at 4.7:1.
  static const blue = Color(0xFF0071E3);

  /// System blue in the dark appearance, as macOS draws it. White on it is
  /// 3.6:1 -- no blue both reads as text on a dark window and carries
  /// white text at 4.5:1 -- and like macOS this keeps white.
  static const blueDark = Color(0xFF0A84FF);

  static const _light = ColorScheme(
    brightness: Brightness.light,
    primary: blue,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFDCEBFF),
    onPrimaryContainer: Color(0xFF00357A),
    secondary: Color(0xFF6E6E73),
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFE8E8ED),
    onSecondaryContainer: Color(0xFF1D1D1F),
    tertiary: Color(0xFF5856D6),
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFE5E4FA),
    onTertiaryContainer: Color(0xFF1E1B6B),
    error: Color(0xFFD70015),
    onError: Colors.white,
    errorContainer: Color(0xFFFFE5E7),
    onErrorContainer: Color(0xFF7A000C),
    surface: Colors.white,
    onSurface: Color(0xFF1D1D1F),
    onSurfaceVariant: Color(0xFF6E6E73),
    surfaceDim: Color(0xFFE5E5EA),
    surfaceBright: Colors.white,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: Color(0xFFF9F9FB),
    surfaceContainer: Color(0xFFF2F2F7),
    surfaceContainerHigh: Color(0xFFEBEBF0),
    surfaceContainerHighest: Color(0xFFE5E5EA),
    outline: Color(0xFF8E8E93),
    outlineVariant: Color(0xFFE5E5EA),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: Color(0xFF1D1D1F),
    onInverseSurface: Color(0xFFF5F5F7),
    inversePrimary: blueDark,
    surfaceTint: Colors.transparent,
  );

  static const _dark = ColorScheme(
    brightness: Brightness.dark,
    primary: blueDark,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFF0A3D73),
    onPrimaryContainer: Color(0xFFDCEBFF),
    secondary: Color(0xFF98989D),
    onSecondary: Color(0xFF1D1D1F),
    secondaryContainer: Color(0xFF3A3A3C),
    onSecondaryContainer: Color(0xFFF5F5F7),
    tertiary: Color(0xFF5E5CE6),
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFF2D2B6B),
    onTertiaryContainer: Color(0xFFE5E4FA),
    error: Color(0xFFFF453A),
    onError: Colors.white,
    errorContainer: Color(0xFF5C1512),
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Color(0xFF1E1E1E),
    onSurface: Color(0xFFF5F5F7),
    onSurfaceVariant: Color(0xFF98989D),
    surfaceDim: Color(0xFF161616),
    surfaceBright: Color(0xFF3A3A3C),
    surfaceContainerLowest: Color(0xFF161616),
    surfaceContainerLow: Color(0xFF232325),
    surfaceContainer: Color(0xFF28282A),
    surfaceContainerHigh: Color(0xFF2C2C2E),
    surfaceContainerHighest: Color(0xFF3A3A3C),
    outline: Color(0xFF8E8E93),
    outlineVariant: Color(0xFF38383A),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: Color(0xFFF5F5F7),
    onInverseSurface: Color(0xFF1D1D1F),
    inversePrimary: blue,
    surfaceTint: Colors.transparent,
  );

  /// Apple's system colours in the slots nemo's palette has always had
  /// (teal, blue, purple, pink, red, orange, green, grey): a list keeps its
  /// colour across styles and on devices still running an older build.
  /// Teal, orange and green are deepened just enough to be 3:1 on white.
  static const lightColors = NemoColors(
    priorityLow: blue,
    priorityMedium: Color(0xFFD47C00),
    priorityHigh: Color(0xFFFF3B30),
    overdue: Color(0xFFD70015),
    listPalette: [
      Color(0xFF2B9EB2),
      blue,
      Color(0xFFAF52DE),
      Color(0xFFFF2D55),
      Color(0xFFFF3B30),
      Color(0xFFD47C00),
      Color(0xFF2CA74B),
      Color(0xFF8E8E93),
    ],
    sidebar: Color(0xFFF2F2F5),
    separator: Color(0x1A000000),
    selection: Color(0x14000000),
    tintedMetaText: false,
  );

  static const darkColors = NemoColors(
    priorityLow: blueDark,
    priorityMedium: Color(0xFFFF9F0A),
    priorityHigh: Color(0xFFFF453A),
    overdue: Color(0xFFFF453A),
    listPalette: [
      Color(0xFF40C8E0),
      blueDark,
      Color(0xFFBF5AF2),
      Color(0xFFFF375F),
      Color(0xFFFF453A),
      Color(0xFFFF9F0A),
      Color(0xFF30D158),
      Color(0xFF98989D),
    ],
    sidebar: Color(0xFF28282A),
    separator: Color(0x24FFFFFF),
    selection: Color(0x1AFFFFFF),
    tintedMetaText: false,
  );

  static ThemeData light() => _build(_light, lightColors);

  static ThemeData dark() => _build(_dark, darkColors);

  static ThemeData _build(ColorScheme scheme, NemoColors nemo) {
    final isLight = scheme.brightness == Brightness.light;
    final textTheme = manropeTextTheme(scheme);
    // Raised surfaces: white on a white window, lifted by a hairline and
    // the faintest shadow; in the dark, a step lighter than the window.
    final raised = isLight ? Colors.white : scheme.surfaceContainerHigh;
    final field = isLight ? const Color(0x0D000000) : const Color(0x14FFFFFF);
    const capsule = StadiumBorder();
    final hairline = BorderSide(color: nemo.separator, width: 0.5);
    WidgetStateProperty<Color?> selectedOr(Color selected, Color other) =>
        WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? selected : other,
        );
    final label = textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600);
    final buttonStyle = ButtonStyle(
      shape: const WidgetStatePropertyAll(capsule),
      textStyle: WidgetStatePropertyAll(label),
      elevation: const WidgetStatePropertyAll(0),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      extensions: [nemo, const AppStyleTheme(AppStyle.macos)],
      scaffoldBackgroundColor: scheme.surface,
      canvasColor: scheme.surface,
      // macOS highlights what is pressed and hovered; it does not ripple.
      splashFactory: NoSplash.splashFactory,
      highlightColor: scheme.onSurface.withValues(alpha: 0.08),
      hoverColor: scheme.onSurface.withValues(alpha: 0.04),
      focusColor: scheme.primary.withValues(alpha: 0.12),
      dividerColor: nemo.separator,
      dividerTheme: DividerThemeData(
        color: nemo.separator,
        thickness: 0.5,
        space: 1,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: field,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        // The focus ring: the accent, soft, just outside the field.
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: scheme.primary.withValues(alpha: 0.5),
            width: 2.5,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        margin: EdgeInsets.zero,
        color: raised,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: isLight ? 0.35 : 0.6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: hairline,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: raised,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: hairline,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        showDragHandle: true,
        backgroundColor: raised,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: scheme.onSurfaceVariant.withValues(alpha: 0.4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: raised,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: hairline,
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(raised),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: hairline,
            ),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        focusElevation: 2,
        hoverElevation: 3,
        highlightElevation: 1,
        shape: capsule,
        extendedTextStyle: label,
      ),
      filledButtonTheme: FilledButtonThemeData(style: buttonStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(style: buttonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: buttonStyle.copyWith(
          side: WidgetStatePropertyAll(
            BorderSide(color: scheme.outline.withValues(alpha: 0.5)),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(style: buttonStyle),
      navigationBarTheme: NavigationBarThemeData(
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 64,
        // A tab bar tints what is selected; it draws no pill behind it.
        indicatorColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: s.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      chipTheme: ChipThemeData(
        shape: capsule,
        side: BorderSide(color: scheme.outline.withValues(alpha: 0.35)),
        backgroundColor: Colors.transparent,
        selectedColor: scheme.primary.withValues(alpha: 0.14),
        labelStyle: textTheme.labelLarge,
      ),
      listTileTheme: ListTileThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        selectedTileColor: nemo.selection,
        selectedColor: scheme.onSurface,
        iconColor: scheme.onSurfaceVariant,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          shape: const WidgetStatePropertyAll(capsule),
          side: WidgetStatePropertyAll(
            BorderSide(color: scheme.outline.withValues(alpha: 0.35)),
          ),
          backgroundColor: selectedOr(
            scheme.primary.withValues(alpha: 0.14),
            Colors.transparent,
          ),
          foregroundColor: selectedOr(scheme.primary, scheme.onSurface),
          textStyle: WidgetStatePropertyAll(label),
        ),
      ),
      // A macOS switch: a white knob on the accent when on, on grey when off.
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: selectedOr(
          scheme.primary,
          isLight ? const Color(0x29000000) : const Color(0x33FFFFFF),
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        thumbIcon: const WidgetStatePropertyAll(null),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        side: BorderSide(color: scheme.outline, width: 1.2),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: nemo.separator,
        circularTrackColor: nemo.separator,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        radius: const Radius.circular(8),
        thickness: const WidgetStatePropertyAll(6),
        thumbColor: WidgetStatePropertyAll(
          scheme.onSurface.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}
