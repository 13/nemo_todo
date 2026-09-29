import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nemo/core/theme/app_style.dart';
import 'package:nemo/core/theme/nemo_colors.dart';
import 'package:nemo/core/theme/nemo_theme.dart';
import 'package:nemo/core/widgets/app_icon.dart';

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

  static ThemeData light({Color? accent}) =>
      _build(accented(_light, accent), lightColors);

  static ThemeData dark({Color? accent}) =>
      _build(accented(_dark, accent), darkColors);

  /// [desktop] -- a macOS theme -- as iOS draws it, for a phone-sized
  /// window: the same colours and shapes in iOS's larger type.
  ///
  /// Rebuilt whole rather than given new type alone: the components --
  /// buttons, chips, the toolbar's title -- take their type when built.
  static ThemeData phone(ThemeData desktop) => _build(
    desktop.colorScheme,
    desktop.extension<NemoColors>()!,
    phone: true,
  );

  static ThemeData _build(
    ColorScheme scheme,
    NemoColors nemo, {
    bool phone = false,
  }) {
    final isLight = scheme.brightness == Brightness.light;
    final textTheme = appleTextTheme(scheme, phone: phone);
    // Raised surfaces: white on a white window, lifted by a hairline and
    // the faintest shadow; in the dark, a step lighter than the window.
    final raised = isLight ? Colors.white : scheme.surfaceContainerHigh;
    final field = isLight ? const Color(0x0D000000) : const Color(0x14FFFFFF);
    final track = isLight ? const Color(0x14000000) : const Color(0x1FFFFFFF);
    const capsule = StadiumBorder();
    final hairline = BorderSide(color: nemo.separator, width: 0.5);
    WidgetStateProperty<Color?> selectedOr(Color selected, Color other) =>
        WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? selected : other,
        );
    Color selectedColor(Color selected, Color other) =>
        WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.selected) ? selected : other,
        );
    final label = textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600);
    // Controls keep the arrow, as on a Mac.
    const arrow = WidgetStatePropertyAll<MouseCursor>(SystemMouseCursors.basic);
    // The accent where it is a ground for white: a button, the chosen day.
    // Dark's system blue is 3.6:1 under white, so there it deepens to the
    // blue white reads on, as an accent never needs to.
    final fill = legibleOn(scheme.primary, [scheme.onPrimary]);
    WidgetStateProperty<Color?> filledWhenSelected() =>
        WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? fill : null,
        );
    final buttonStyle = ButtonStyle(
      mouseCursor: arrow,
      shape: const WidgetStatePropertyAll(capsule),
      textStyle: WidgetStatePropertyAll(label),
      elevation: const WidgetStatePropertyAll(0),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      fontFamily: 'Inter',
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
      // Apple's back is a chevron, not Material's arrow.
      actionIconTheme: ActionIconThemeData(
        backButtonIconBuilder: (_) =>
            const AppIcon(Icons.arrow_back_ios_new_rounded, size: 20),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        systemOverlayStyle: systemBarsFor(scheme),
        // Clear over the window, and once the content has scrolled under
        // it, a soft edge along its foot, as a macOS 26 toolbar shows.
        backgroundColor: WidgetStateColor.resolveWith(
          (s) => s.contains(WidgetState.scrolledUnder)
              ? scheme.surface
              : Colors.transparent,
        ),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black.withValues(alpha: isLight ? 0.3 : 0.8),
        titleTextStyle: textTheme.titleLarge,
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: field,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        // A bezel: the faintest edge around the fill.
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: hairline,
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
      // An alert on a Mac is narrow: a question, not a page.
      dialogTheme: DialogThemeData(
        constraints: const BoxConstraints(minWidth: 260, maxWidth: 400),
        backgroundColor: raised,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
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
        mouseCursor: arrow,
        color: raised,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.25),
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
      filledButtonTheme: FilledButtonThemeData(
        style: buttonStyle.copyWith(
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? null : fill,
          ),
        ),
      ),
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
      iconButtonTheme: const IconButtonThemeData(
        style: ButtonStyle(mouseCursor: arrow),
      ),
      listTileTheme: ListTileThemeData(
        mouseCursor: arrow,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        selectedTileColor: nemo.selection,
        selectedColor: scheme.onSurface,
        iconColor: scheme.onSurfaceVariant,
      ),
      // A Mac's segmented control: a grey track, the chosen segment raised
      // out of it in white, and no accent -- choosing is not an action.
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          mouseCursor: arrow,
          shape: const WidgetStatePropertyAll(capsule),
          side: WidgetStatePropertyAll(BorderSide(color: track, width: 2)),
          backgroundColor: selectedOr(
            isLight ? Colors.white : const Color(0xFF636366),
            track,
          ),
          foregroundColor: WidgetStatePropertyAll(scheme.onSurface),
          textStyle: WidgetStatePropertyAll(label),
          // Compact for a pointer; a finger's 48 px on a phone.
          visualDensity: phone ? VisualDensity.standard : VisualDensity.compact,
        ),
      ),
      // A macOS switch: a white knob on the accent when on, on grey when off.
      switchTheme: SwitchThemeData(
        mouseCursor: arrow,
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: selectedOr(
          scheme.primary,
          isLight ? const Color(0x29000000) : const Color(0x33FFFFFF),
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        thumbIcon: const WidgetStatePropertyAll(null),
      ),
      checkboxTheme: CheckboxThemeData(
        mouseCursor: arrow,
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
      // A calendar popover rather than Android's tonal header: the raised
      // surface, a quiet header, and blue only for what is chosen.
      datePickerTheme: DatePickerThemeData(
        backgroundColor: raised,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.25),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: hairline,
        ),
        headerBackgroundColor: Colors.transparent,
        headerForegroundColor: scheme.onSurface,
        headerHeadlineStyle: textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        dividerColor: nemo.separator,
        todayBorder: BorderSide(color: scheme.primary),
        todayForegroundColor: selectedOr(scheme.onPrimary, scheme.primary),
        todayBackgroundColor: filledWhenSelected(),
        dayBackgroundColor: filledWhenSelected(),
        yearBackgroundColor: filledWhenSelected(),
        dayOverlayColor: WidgetStatePropertyAll(
          scheme.onSurface.withValues(alpha: 0.06),
        ),
        yearOverlayColor: WidgetStatePropertyAll(
          scheme.onSurface.withValues(alpha: 0.06),
        ),
        cancelButtonStyle: buttonStyle,
        confirmButtonStyle: buttonStyle,
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: raised,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: hairline,
        ),
        hourMinuteShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        hourMinuteColor: selectedColor(
          scheme.primary.withValues(alpha: 0.14),
          field,
        ),
        hourMinuteTextColor: selectedColor(scheme.primary, scheme.onSurface),
        dayPeriodShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: hairline,
        ),
        dayPeriodBorderSide: hairline,
        dayPeriodColor: selectedColor(
          scheme.primary.withValues(alpha: 0.14),
          Colors.transparent,
        ),
        dayPeriodTextColor: selectedColor(
          scheme.primary,
          scheme.onSurfaceVariant,
        ),
        dialBackgroundColor: field,
        dialHandColor: fill,
        dialTextColor: selectedColor(scheme.onPrimary, scheme.onSurface),
        entryModeIconColor: scheme.onSurfaceVariant,
        cancelButtonStyle: buttonStyle,
        confirmButtonStyle: buttonStyle,
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

/// Apple's type scales in Inter, coloured for [scheme]: the Mac's for a
/// window, iOS's larger one for a phone ([phone]).
///
/// Material's roles, filled with Apple's sizes: 13 pt body and 11 pt
/// captions on a Mac, 17 and 13 on a phone. Tracking follows Inter's own
/// formula, tighter as the type grows, where Material spaces every size
/// out -- half a point on body text -- which reads as Android at once.
TextTheme appleTextTheme(ColorScheme scheme, {bool phone = false}) {
  // On Material's own base, so a theme changing style animates between
  // styles that agree on everything but these fields.
  final base = Typography.material2021(colorScheme: scheme)
      .englishLike
      .bodyMedium!;
  TextStyle style(double size, FontWeight weight, {double height = 1.25}) =>
      base.copyWith(
        fontFamily: 'Inter',
        fontSize: size,
        fontWeight: weight,
        height: height,
        // Inter's dynamic metrics: tracking = a + b * e^(c * size), in em.
        letterSpacing: size * (-0.0223 + 0.185 * math.exp(-0.1745 * size)),
        color: scheme.onSurface,
        leadingDistribution: TextLeadingDistribution.even,
      );
  const regular = FontWeight.w400;
  const medium = FontWeight.w500;
  const semibold = FontWeight.w600;
  const bold = FontWeight.w700;
  return phone
      ? TextTheme(
          displayLarge: style(40, bold, height: 1.1),
          displayMedium: style(34, bold, height: 1.1),
          displaySmall: style(30, bold, height: 1.15),
          headlineLarge: style(34, bold, height: 1.15),
          headlineMedium: style(28, bold, height: 1.2),
          headlineSmall: style(22, bold),
          titleLarge: style(30, bold, height: 1.15),
          titleMedium: style(17, semibold),
          titleSmall: style(15, semibold),
          bodyLarge: style(17, regular, height: 1.3),
          bodyMedium: style(15, regular, height: 1.3),
          bodySmall: style(13, regular),
          labelLarge: style(15, medium),
          labelMedium: style(13, regular),
          labelSmall: style(11, medium),
        )
      : TextTheme(
          displayLarge: style(34, bold, height: 1.1),
          displayMedium: style(30, bold, height: 1.1),
          displaySmall: style(26, bold, height: 1.15),
          headlineLarge: style(26, bold, height: 1.15),
          headlineMedium: style(22, bold, height: 1.2),
          headlineSmall: style(17, bold),
          titleLarge: style(24, bold, height: 1.15),
          titleMedium: style(15, semibold),
          titleSmall: style(13, semibold),
          bodyLarge: style(14, regular, height: 1.3),
          bodyMedium: style(13, regular, height: 1.3),
          bodySmall: style(11, regular),
          labelLarge: style(13, medium),
          labelMedium: style(11, medium),
          labelSmall: style(10, medium),
        );
}
