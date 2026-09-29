import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// The macOS style's Phosphor fonts are subset to the glyphs `AppIcon`
/// maps to (tool/subset_phosphor.sh). A mapping added without subsetting
/// again compiles and passes every other test, then draws an empty box:
/// this reads each font's own character map to catch that.
void main() {
  final source = File('lib/core/widgets/app_icon.dart').readAsStringSync();
  final named = RegExp(
    r"IconData\(\s*(0x[0-9a-f]+),\s*fontFamily:\s*'(Phosphor\w+)'",
  );

  for (final family in ['PhosphorRegular', 'PhosphorFill']) {
    test('$family holds every glyph AppIcon draws from it', () {
      final wanted = {
        for (final m in named.allMatches(source))
          if (m.group(2) == family) int.parse(m.group(1)!),
      };
      expect(wanted, isNotEmpty);
      final font = File('assets/fonts/$family.ttf').readAsBytesSync();
      final held = _characters(ByteData.sublistView(font));
      final missing = wanted.difference(held).map((c) => c.toRadixString(16));
      expect(
        missing,
        isEmpty,
        reason: 'run tool/subset_phosphor.sh and commit the fonts',
      );
    });
  }
}

/// Every character a TrueType font's format 4 (Unicode BMP) cmap maps to
/// a glyph.
Set<int> _characters(ByteData font) {
  final tables = font.getUint16(4);
  int? cmap;
  for (var i = 0; i < tables; i++) {
    final record = 12 + 16 * i;
    if (font.getUint32(record) == 0x636d6170) {
      cmap = font.getUint32(record + 8);
    }
  }
  if (cmap == null) throw const FormatException('no cmap table');
  final chars = <int>{};
  final subtables = font.getUint16(cmap + 2);
  for (var i = 0; i < subtables; i++) {
    final at = cmap + font.getUint32(cmap + 4 + 8 * i + 4);
    if (font.getUint16(at) != 4) continue;
    final segments = font.getUint16(at + 6) ~/ 2;
    final ends = at + 14;
    final starts = ends + 2 * segments + 2;
    final deltas = starts + 2 * segments;
    final offsets = deltas + 2 * segments;
    for (var s = 0; s < segments; s++) {
      final end = font.getUint16(ends + 2 * s);
      final start = font.getUint16(starts + 2 * s);
      final delta = font.getUint16(deltas + 2 * s);
      final offset = font.getUint16(offsets + 2 * s);
      for (var c = start; c <= end && c != 0xffff; c++) {
        final int glyph;
        if (offset == 0) {
          glyph = (c + delta) & 0xffff;
        } else {
          final g = font.getUint16(offsets + 2 * s + offset + 2 * (c - start));
          glyph = g == 0 ? 0 : (g + delta) & 0xffff;
        }
        if (glyph != 0) chars.add(c);
      }
    }
  }
  return chars;
}
