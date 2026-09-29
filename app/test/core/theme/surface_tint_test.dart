import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/theme/surface_tint.dart';

void main() {
  const window = Color(0xFFF5F8F8);
  const container = Color(0xFFECF3F2);
  const darkWindow = Color(0xFF0E1616);
  const pink = Color(0xFFD64577);

  HSLColor hsl(Color c) => HSLColor.fromColor(c);

  test('subtle with no accent is the colour itself', () {
    for (final c in [window, container, darkWindow]) {
      expect(tinted(c, SurfaceTint.subtle), c);
    }
  });

  test('none is grey', () {
    for (final c in [window, container, darkWindow]) {
      expect(hsl(tinted(c, SurfaceTint.none)).saturation, 0);
      expect(hsl(tinted(c, SurfaceTint.none, accent: pink)).saturation, 0);
    }
  });

  test('lightness is kept at every level and accent', () {
    for (final c in [window, container, darkWindow]) {
      for (final t in SurfaceTint.values) {
        for (final a in [null, pink]) {
          expect(
            hsl(tinted(c, t, accent: a)).lightness,
            closeTo(hsl(c).lightness, 0.01),
            reason: '$c $t $a',
          );
        }
      }
    }
  });

  test('strong is more saturated than subtle, and no more than full', () {
    for (final c in [window, container, darkWindow]) {
      final subtle = hsl(tinted(c, SurfaceTint.subtle, accent: pink));
      final strong = hsl(tinted(c, SurfaceTint.strong, accent: pink));
      expect(strong.saturation, greaterThan(subtle.saturation));
      expect(strong.saturation, lessThanOrEqualTo(1));
    }
    // Saturation ~0.43: x2.5 passes 1 and must clamp.
    const vivid = Color(0xFF3FA0A0);
    expect(hsl(tinted(vivid, SurfaceTint.strong)).saturation, closeTo(1, 0.01));
  });

  test('an accent gives its hue', () {
    final t = tinted(container, SurfaceTint.subtle, accent: pink);
    // A faint colour's hue is coarse in 8-bit channels.
    expect(hsl(t).hue, closeTo(hsl(pink).hue, 10));
  });

  test('white and black stay as they are', () {
    for (final c in [Colors.white, Colors.black]) {
      for (final t in SurfaceTint.values) {
        expect(tinted(c, t, accent: pink), c, reason: '$c $t');
      }
    }
  });
}
