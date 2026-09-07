import 'package:flutter/material.dart';
import 'package:nemo/core/theme/nemo_colors.dart';

/// Material 3 theme seeded from nemo's deep ocean teal.
class AppTheme {
  static const seed = Color(0xFF0E7C86);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: seed).copyWith(
      primary: seed,
      surface: Colors.white,
      onSurface: const Color(0xFF16211F),
      onSurfaceVariant: const Color(0xFF45524F),
      outlineVariant: const Color(0xFFD9E3E1),
      surfaceContainerHighest: const Color(0xFFECF3F2),
    );
    return _base(
      scheme,
      NemoColors.light,
    ).copyWith(scaffoldBackgroundColor: const Color(0xFFF5F8F8));
  }

  static ThemeData dark() {
    final scheme =
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
        );
    return _base(
      scheme,
      NemoColors.dark,
    ).copyWith(scaffoldBackgroundColor: const Color(0xFF0E1616));
  }

  static ThemeData _base(ColorScheme scheme, NemoColors nemo) {
    final textTheme = Typography.material2021(colorScheme: scheme).englishLike
        .apply(
          fontFamily: 'Manrope',
          bodyColor: scheme.onSurface,
          displayColor: scheme.onSurface,
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      extensions: [nemo],
      appBarTheme: AppBarTheme(
        centerTitle: false,
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
