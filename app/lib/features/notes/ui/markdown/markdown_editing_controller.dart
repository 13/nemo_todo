import 'package:flutter/material.dart';
import 'package:nemo/features/notes/ui/markdown/markdown_spans.dart';

/// A text controller that paints its markdown as it is typed.
///
/// Only the painting changes: [text] is never rewritten, so the cursor,
/// selection, IME and undo work exactly as in a plain field, and what the
/// person sees is character-for-character what gets stored.
class MarkdownEditingController extends TextEditingController {
  MarkdownEditingController({super.text});

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    required bool withComposing,
    TextStyle? style,
  }) {
    final base = style ?? const TextStyle();
    final theme = Theme.of(context);
    final ranges = parseMarkdownRanges(text);
    final composing = withComposing && value.isComposingRangeValid
        ? value.composing
        : TextRange.empty;
    if (ranges.isEmpty && !composing.isValid) {
      return TextSpan(style: base, text: text);
    }

    final cuts = <int>{0, text.length};
    for (final r in ranges) {
      cuts
        ..add(r.start)
        ..add(r.end);
    }
    if (composing.isValid && !composing.isCollapsed) {
      cuts
        ..add(composing.start)
        ..add(composing.end);
    }
    final sorted = cuts.toList()..sort();

    final children = <TextSpan>[];
    for (var i = 0; i + 1 < sorted.length; i++) {
      final a = sorted[i];
      final b = sorted[i + 1];
      if (a == b) continue;
      final styles = {
        for (final r in ranges)
          if (r.start <= a && b <= r.end) r.style,
      };
      var piece = markdownStyle(styles, base, theme);
      if (composing.isValid && composing.start <= a && b <= composing.end) {
        piece = piece.copyWith(
          decoration: TextDecoration.combine([
            if (piece.decoration != null) piece.decoration!,
            TextDecoration.underline,
          ]),
        );
      }
      children.add(TextSpan(text: text.substring(a, b), style: piece));
    }
    return TextSpan(style: base, children: children);
  }
}

/// How a run of text covered by [styles] looks, on top of [base].
TextStyle markdownStyle(Set<MdStyle> styles, TextStyle base, ThemeData theme) {
  final t = theme.textTheme;
  final c = theme.colorScheme;
  var s = base;

  final headingSize = switch (styles) {
    _ when styles.contains(MdStyle.h1) => t.headlineSmall?.fontSize,
    _ when styles.contains(MdStyle.h2) => t.titleLarge?.fontSize,
    _ when styles.contains(MdStyle.h3) => t.titleMedium?.fontSize,
    _
        when styles.contains(MdStyle.h4) ||
            styles.contains(MdStyle.h5) ||
            styles.contains(MdStyle.h6) =>
      t.titleSmall?.fontSize,
    _ => null,
  };
  if (headingSize != null) {
    s = s.copyWith(fontSize: headingSize, fontWeight: FontWeight.w700);
  }

  if (styles.contains(MdStyle.bold)) {
    s = s.copyWith(fontWeight: FontWeight.w700);
  }
  if (styles.contains(MdStyle.italic) || styles.contains(MdStyle.quote)) {
    s = s.copyWith(fontStyle: FontStyle.italic);
  }
  if (styles.contains(MdStyle.code) || styles.contains(MdStyle.codeBlock)) {
    s = s.copyWith(
      fontFamily: 'monospace',
      fontFamilyFallback: const ['Courier New', 'Courier'],
      backgroundColor: c.surfaceContainerHighest,
    );
  }

  final decorations = <TextDecoration>[
    if (styles.contains(MdStyle.strike) || styles.contains(MdStyle.taskDone))
      TextDecoration.lineThrough,
    if (styles.contains(MdStyle.link)) TextDecoration.underline,
  ];
  if (decorations.isNotEmpty) {
    s = s.copyWith(decoration: TextDecoration.combine(decorations));
  }

  if (styles.contains(MdStyle.quote) || styles.contains(MdStyle.taskDone)) {
    s = s.copyWith(color: c.onSurfaceVariant);
  }
  if (styles.contains(MdStyle.link)) {
    s = s.copyWith(color: c.primary);
  }
  // Markers last, so they stay faint whatever they sit inside.
  if (styles.contains(MdStyle.listMarker)) {
    s = s.copyWith(color: c.onSurfaceVariant.withValues(alpha: 0.8));
  }
  if (styles.contains(MdStyle.marker)) {
    s = s.copyWith(color: c.onSurfaceVariant.withValues(alpha: 0.45));
  }
  return s;
}
