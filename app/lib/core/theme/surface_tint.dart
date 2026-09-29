import 'package:flutter/material.dart';

/// How much of the accent the nemo style's window and surfaces take on,
/// chosen in Settings beside the accent.
enum SurfaceTint {
  /// Plain greys.
  none,

  /// As nemo has always been: a faint cast; the default.
  subtle,

  /// A cast you notice.
  strong,
}

/// [color] with the hue of [accent], where there is one, and its
/// saturation scaled for [tint]; its lightness as it was.
///
/// Lightness is what nemo's hand-tuned greys differ in, and what keeps
/// text readable on them, so only the cast changes. White and black have
/// no cast to change and come back as they went in.
///
/// An accent with little colour of its own, like grey, lends as little:
/// its backgrounds stay near grey rather than taking on its faint hue.
Color tinted(Color color, SurfaceTint tint, {Color? accent}) {
  // The default theme is today's to the bit, not to within rounding.
  if (tint == SurfaceTint.subtle && accent == null) return color;
  final hsl = HSLColor.fromColor(color);
  final from = accent == null ? null : HSLColor.fromColor(accent);
  final factor = switch (tint) {
    SurfaceTint.none => 0.0,
    SurfaceTint.subtle => 1.0,
    SurfaceTint.strong => 2.5,
  };
  // Every list colour but grey is at least this saturated.
  const colourful = 0.4;
  final lent = from == null ? 1.0 : (from.saturation / colourful).clamp(0, 1);
  return hsl
      .withHue(from?.hue ?? hsl.hue)
      .withSaturation((hsl.saturation * factor * lent).clamp(0.0, 1.0))
      .toColor();
}
