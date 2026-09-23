import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nemo/features/notes/ui/markdown/markdown_editing_controller.dart';
import 'package:nemo/features/notes/ui/markdown/markdown_spans.dart';

final _fenceLine = RegExp(r'^\s*```.*$', multiLine: true);
final _taskBox = RegExp(r'\[([ xX])\]');
final _bullet = RegExp('^[-*+]');

/// A note body as read-only styled text, for a preview: the markdown the
/// editor paints, but with its markers gone -- `**`, `#`, link URLs and
/// code fences hidden, list markers as bullets and task boxes as boxes.
///
/// Headings are held to a little above [base] so one cannot set the size
/// of a card or a row the way a rendered document's would.
TextSpan markdownPreviewSpan(String text, TextStyle base, ThemeData theme) {
  final ranges = parseMarkdownRanges(text);

  // Characters dropped from the preview: the markers, and each fence line
  // along with its line break.
  final hidden = <(int, int)>[
    for (final r in ranges)
      if (r.style == MdStyle.marker) (r.start, r.end),
    for (final m in _fenceLine.allMatches(text))
      (m.start, math.min(m.end + 1, text.length)),
  ];
  bool isHidden(int a, int b) => hidden.any((h) => h.$1 <= a && b <= h.$2);

  final cuts = <int>{0, text.length};
  for (final r in ranges) {
    cuts
      ..add(r.start)
      ..add(r.end);
  }
  for (final h in hidden) {
    cuts
      ..add(h.$1)
      ..add(h.$2);
  }
  final sorted = cuts.toList()..sort();

  final maxSize = (base.fontSize ?? 14) * 1.2;
  final children = <TextSpan>[];
  for (var i = 0; i + 1 < sorted.length; i++) {
    final a = sorted[i];
    final b = sorted[i + 1];
    if (a == b || isHidden(a, b)) continue;
    final styles = {
      for (final r in ranges)
        if (r.start <= a && b <= r.end) r.style,
    };
    var style = markdownStyle(styles, base, theme);
    if ((style.fontSize ?? 0) > maxSize) {
      style = style.copyWith(fontSize: maxSize);
    }
    var piece = text.substring(a, b);
    if (styles.contains(MdStyle.listMarker)) piece = _listMarker(piece);
    children.add(TextSpan(text: piece, style: style));
  }
  return TextSpan(style: base, children: children);
}

/// `- [x] ` as a ticked box, `- [ ] ` as an empty one, `- ` as a bullet;
/// a numbered marker stays as written.
String _listMarker(String marker) {
  final box = _taskBox.firstMatch(marker);
  if (box != null) return box.group(1) == ' ' ? '☐ ' : '☑ ';
  return marker.replaceFirst(_bullet, '•');
}
