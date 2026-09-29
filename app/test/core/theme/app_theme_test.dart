import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/theme/app_style.dart';
import 'package:nemo/core/theme/app_theme.dart';
import 'package:nemo/core/theme/nemo_colors.dart';

void main() {
  double contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final light = la > lb ? la : lb;
    final dark = la > lb ? lb : la;
    return (light + 0.05) / (dark + 0.05);
  }

  for (final style in AppStyle.values) {
    for (final brightness in Brightness.values) {
      final name = '${style.name} ${brightness.name}';
      final theme = AppTheme.build(style, brightness);
      final s = theme.colorScheme;
      final nemo = theme.extension<NemoColors>()!;
      final window = theme.scaffoldBackgroundColor;

      test('$name: text reads on its surfaces', () {
        expect(s.brightness, brightness);
        expect(theme.extension<AppStyleTheme>()!.style, style);
        expect(theme.textTheme.bodyLarge?.fontFamily, 'Manrope');
        for (final bg in [s.surface, window]) {
          expect(contrast(s.onSurface, bg), greaterThan(7));
          expect(contrast(s.onSurfaceVariant, bg), greaterThan(4.5));
          // Overdue and today's date are the coloured text on a tile.
          expect(contrast(nemo.overdue, bg), greaterThan(4.5));
          expect(contrast(s.primary, bg), greaterThan(4.5));
        }
        // No blue is both text on a dark window and a ground for white
        // text at 4.5:1; macOS keeps white on system blue at 3.6:1, which
        // is what WCAG asks of controls and bold labels.
        final onPrimary = style == AppStyle.macos && brightness == .dark
            ? 3.5
            : 4.5;
        expect(contrast(s.onPrimary, s.primary), greaterThan(onPrimary));
      });

      test('$name: list and priority colours show as icons', () {
        expect(nemo.listPalette, hasLength(8));
        for (final c in [
          ...nemo.listPalette,
          nemo.priorityLow,
          nemo.priorityMedium,
          nemo.priorityHigh,
        ]) {
          // nemo's own amber is 2.6:1 on its light window, as it has
          // always been; the nemo style is kept exactly as it was.
          if (style == AppStyle.nemo && c == const Color(0xFFD98A00)) continue;
          expect(contrast(c, window), greaterThan(3), reason: '$c');
        }
      });
    }
  }

  test('macOS neutrals are grey, not tinted towards the accent', () {
    for (final b in Brightness.values) {
      final s = AppTheme.build(AppStyle.macos, b).colorScheme;
      for (final c in [
        s.surface,
        s.surfaceContainerLow,
        s.surfaceContainer,
        s.surfaceContainerHigh,
        s.surfaceContainerHighest,
        s.onSurface,
        s.onSurfaceVariant,
        s.outlineVariant,
      ]) {
        // Chroma, not HSL saturation, which balloons near white and black.
        final channels = [c.r, c.g, c.b];
        final chroma =
            channels.reduce((a, b) => a > b ? a : b) -
            channels.reduce((a, b) => a < b ? a : b);
        expect(chroma, lessThan(0.03), reason: '$c');
      }
    }
  });

  test('the nemo style is the theme nemo has always had', () {
    expect(AppTheme.light().colorScheme.primary, AppTheme.seed);
    expect(AppTheme.light().scaffoldBackgroundColor, const Color(0xFFF5F8F8));
    expect(AppTheme.dark().scaffoldBackgroundColor, const Color(0xFF0E1616));
    expect(NemoColors.light.tintedMetaText, isTrue);
  });

  test('the Material style takes the wallpaper where there is one', () {
    final wallpaper = (
      light: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      dark: ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        brightness: Brightness.dark,
      ),
    );
    for (final b in Brightness.values) {
      final theme = AppTheme.build(AppStyle.material, b, wallpaper: wallpaper);
      final expected = b == Brightness.light ? wallpaper.light : wallpaper.dark;
      expect(theme.colorScheme.primary, expected.primary);
      expect(theme.extension<NemoColors>()!.overdue, expected.error);
    }
  });

  test("the web loading screen paints in each style's colours", () {
    // web/index.html repeats them in CSS; the page shows before any Dart runs.
    final html = File('web/index.html').readAsStringSync();
    String hex(Color c) =>
        '#${c.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
    for (final style in AppStyle.values) {
      for (final b in Brightness.values) {
        final theme = AppTheme.build(style, b);
        final css =
            '--bg: ${hex(theme.scaffoldBackgroundColor)}; '
            '--mark: ${hex(theme.colorScheme.primary)};';
        expect(html, contains(css), reason: '${style.name} ${b.name}');
      }
    }
  });

  test('NemoColors palette wraps and priorities map', () {
    const c = NemoColors.light;
    expect(c.listColor(8), c.listColor(0));
    expect(c.priority(0), isNull);
    expect(c.priority(3), c.priorityHigh);
    final mid = c.lerp(NemoColors.dark, 0.5);
    expect(mid.listPalette, hasLength(8));
    expect(c.copyWith(overdue: Colors.black).overdue, Colors.black);
    expect(
      c.lerp(c.copyWith(tintedMetaText: false), 0.7).tintedMetaText,
      false,
    );
  });
}
