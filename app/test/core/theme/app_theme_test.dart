import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/theme/app_style.dart';
import 'package:nemo/core/theme/app_theme.dart';
import 'package:nemo/core/theme/macos_theme.dart';
import 'package:nemo/core/theme/nemo_colors.dart';
import 'package:nemo/core/theme/surface_tint.dart';

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
        expect(theme.textTheme.bodyLarge?.fontFamily, switch (style) {
          AppStyle.nemo => 'Manrope',
          AppStyle.macos => 'Inter',
          // Android's own; the web's bundled copy is RobotoWeb.
          AppStyle.material => 'Roboto',
        });
        for (final bg in [s.surface, window]) {
          expect(contrast(s.onSurface, bg), greaterThan(7));
          expect(contrast(s.onSurfaceVariant, bg), greaterThan(4.5));
          // Overdue and today's date are the coloured text on a tile.
          expect(contrast(nemo.overdue, bg), greaterThan(4.5));
          expect(contrast(s.primary, bg), greaterThan(4.5));
        }
        // No blue is both text on a dark window and a ground for white
        // text at 4.5:1; macOS keeps white on system blue at 3.6:1 where
        // it marks something, which is what WCAG asks of controls...
        final onPrimary = style == AppStyle.macos && brightness == .dark
            ? 3.5
            : 4.5;
        expect(contrast(s.onPrimary, s.primary), greaterThan(onPrimary));
        // ...and a filled button, whose label is text, takes a deeper blue.
        final fill =
            theme.filledButtonTheme.style?.backgroundColor?.resolve({}) ??
            s.primary;
        expect(contrast(s.onPrimary, fill), greaterThanOrEqualTo(4.5));
      });

      test('$name: Android draws its bars legibly over the app', () {
        final bars = theme.appBarTheme.systemOverlayStyle!;
        final dark = brightness == Brightness.dark;
        // Light icons on a dark window, dark ones on a light window.
        expect(
          bars.statusBarIconBrightness,
          dark ? Brightness.light : Brightness.dark,
        );
        expect(
          bars.systemNavigationBarIconBrightness,
          bars.statusBarIconBrightness,
        );
      });

      test('$name: list and priority colours show as icons', () {
        expect(nemo.listPalette, hasLength(8));
        for (final c in [
          ...nemo.listPalette,
          nemo.priorityLow,
          nemo.priorityMedium,
          nemo.priorityHigh,
        ]) {
          expect(contrast(c, window), greaterThan(3), reason: '$c');
        }
      });
    }
  }

  test('every accent keeps text readable, in every style', () {
    for (final style in AppStyle.values) {
      for (final b in Brightness.values) {
        for (var accent = 0; accent < 8; accent++) {
          final theme = AppTheme.build(style, b, accent: accent);
          final s = theme.colorScheme;
          final why = '${style.name} ${b.name} accent $accent';
          expect(
            contrast(s.onPrimary, s.primary),
            greaterThan(4.5),
            reason: why,
          );
          for (final bg in [s.surface, theme.scaffoldBackgroundColor]) {
            expect(contrast(s.primary, bg), greaterThan(4.5), reason: why);
          }
        }
      }
    }
  });

  test("a list's colour as a task's small text reads, in every style", () {
    for (final style in AppStyle.values) {
      for (final b in Brightness.values) {
        final theme = AppTheme.build(style, b);
        final nemo = theme.extension<NemoColors>()!;
        final grounds = [
          theme.colorScheme.surface,
          theme.scaffoldBackgroundColor,
        ];
        for (final c in nemo.listPalette) {
          final text = legibleOn(c, grounds);
          for (final bg in grounds) {
            expect(
              contrast(text, bg),
              greaterThanOrEqualTo(4.5),
              reason: '${style.name} ${b.name} $c',
            );
          }
          // Only as far from the colour as it has to be: the same hue.
          if (contrast(c, grounds.first) >= 4.5) expect(text, c);
          expect(
            HSLColor.fromColor(text).hue,
            closeTo(HSLColor.fromColor(c).hue, 1),
          );
        }
      }
    }
  });

  test('contrastRatio is WCAG’s, and legibleOn reaches it', () {
    expect(contrastRatio(Colors.black, Colors.white), closeTo(21, 0.01));
    expect(contrastRatio(Colors.white, Colors.white), 1);
    // White on white goes grey, black on black lightens: just far enough.
    for (final c in [Colors.white, Colors.black]) {
      final text = legibleOn(c, [c]);
      expect(contrastRatio(text, c), inInclusiveRange(4.5, 5));
    }
  });

  test("an accent is the chosen colour, and none is the style's own", () {
    final teal = AppTheme.build(AppStyle.macos, Brightness.light, accent: 0);
    expect(
      HSLColor.fromColor(teal.colorScheme.primary).hue,
      closeTo(HSLColor.fromColor(AppTheme.accents(AppStyle.macos)[0]).hue, 15),
    );
    expect(
      AppTheme.build(AppStyle.macos, Brightness.light).colorScheme.primary,
      MacosTheme.blue,
    );
  });

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

  group('surface tint', () {
    test('nemo subtle with no accent is nemo as it was', () {
      final light = AppTheme.build(AppStyle.nemo, Brightness.light);
      expect(light.scaffoldBackgroundColor, const Color(0xFFF5F8F8));
      expect(light.colorScheme.surface, Colors.white);
      expect(light.colorScheme.onSurface, const Color(0xFF16211F));
      expect(light.colorScheme.onSurfaceVariant, const Color(0xFF45524F));
      expect(light.colorScheme.outlineVariant, const Color(0xFFD9E3E1));
      expect(
        light.colorScheme.surfaceContainerHighest,
        const Color(0xFFECF3F2),
      );
      expect(light.extension<NemoColors>(), NemoColors.light);

      final dark = AppTheme.build(AppStyle.nemo, Brightness.dark);
      expect(dark.scaffoldBackgroundColor, const Color(0xFF0E1616));
      expect(dark.colorScheme.surface, const Color(0xFF151F1F));
      expect(dark.colorScheme.onSurface, const Color(0xFFE3ECEB));
      expect(dark.colorScheme.onSurfaceVariant, const Color(0xFFA7B8B6));
      expect(dark.colorScheme.outlineVariant, const Color(0xFF2A3837));
      expect(dark.colorScheme.surfaceContainerHighest, const Color(0xFF1D2A29));
      expect(dark.extension<NemoColors>(), NemoColors.dark);
    });

    for (final brightness in Brightness.values) {
      for (final tint in SurfaceTint.values) {
        for (final accent in [null, 0, 1, 2, 3, 4, 5, 6, 7]) {
          test('nemo ${brightness.name} $tint accent $accent: text reads', () {
            final theme = AppTheme.build(
              AppStyle.nemo,
              brightness,
              accent: accent,
              tint: tint,
            );
            final s = theme.colorScheme;
            final grounds = [
              theme.scaffoldBackgroundColor,
              s.surface,
              s.surfaceContainerHighest,
              theme.extension<NemoColors>()!.sidebar,
            ];
            for (final bg in grounds) {
              expect(contrast(s.onSurface, bg), greaterThanOrEqualTo(4.5));
              expect(
                contrast(s.onSurfaceVariant, bg),
                greaterThanOrEqualTo(4.5),
                reason: 'onSurfaceVariant on $bg',
              );
            }
          });
        }
      }
    }

    test('none is grey, strong more coloured than subtle', () {
      double sat(SurfaceTint t) => HSLColor.fromColor(
        AppTheme.build(
          AppStyle.nemo,
          Brightness.light,
          accent: 3,
          tint: t,
        ).scaffoldBackgroundColor,
      ).saturation;
      expect(sat(SurfaceTint.none), 0);
      expect(sat(SurfaceTint.strong), greaterThan(sat(SurfaceTint.subtle)));
    });

    test('the backgrounds follow a changed accent', () {
      Color window(int accent) => AppTheme.build(
        AppStyle.nemo,
        Brightness.dark,
        accent: accent,
        tint: SurfaceTint.strong,
      ).scaffoldBackgroundColor;
      final pink = HSLColor.fromColor(window(3)).hue;
      final green = HSLColor.fromColor(window(6)).hue;
      expect((pink - green).abs(), greaterThan(60));
    });

    for (final style in [AppStyle.macos, AppStyle.material]) {
      for (final brightness in Brightness.values) {
        test('${style.name} ${brightness.name} ignores the tint', () {
          ThemeData at(SurfaceTint t) =>
              AppTheme.build(style, brightness, accent: 2, tint: t);
          expect(
            at(SurfaceTint.none).colorScheme,
            at(SurfaceTint.strong).colorScheme,
          );
          expect(
            at(SurfaceTint.none).scaffoldBackgroundColor,
            at(SurfaceTint.strong).scaffoldBackgroundColor,
          );
        });
      }
    }
  });
}
