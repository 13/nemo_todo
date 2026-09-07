import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  test('primary on surface and text contrast are readable', () {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      final s = theme.colorScheme;
      expect(contrast(s.onSurface, s.surface), greaterThan(7));
      expect(contrast(s.onPrimary, s.primary), greaterThan(4.5));
      expect(contrast(s.onSurfaceVariant, s.surface), greaterThan(4.5));
      expect(theme.textTheme.bodyLarge?.fontFamily, 'Manrope');
      expect(theme.extension<NemoColors>(), isNotNull);
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
  });
}
