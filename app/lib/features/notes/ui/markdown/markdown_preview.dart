import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:nemo/features/notes/ui/markdown/markdown_editing_controller.dart';
import 'package:nemo/features/notes/ui/markdown/markdown_spans.dart';
import 'package:nemo/features/notes/ui/markdown/note_to_task.dart';

final _fenceLine = RegExp(r'^\s*```.*$', multiLine: true);
final _taskBox = RegExp(r'\[([ xX])\]');
final _bullet = RegExp('^[-*+]');
// The `(url)` after a link's text, one level of balanced parentheses deep,
// as the parser allows.
final _linkTarget = RegExp(r'^\]\(((?:[^()\s]|\([^()\s]*\))+)\)');

/// A note body as read-only styled text for a card or row preview: see
/// [markdownSpan], with headings held near body size so one cannot set the
/// size of a card or a row.
TextSpan markdownPreviewSpan(String text, TextStyle base, ThemeData theme) =>
    markdownSpan(text, base, theme, capHeadings: true);

/// Markdown as read-only styled text: the markup the editor paints, with
/// its markers gone -- `**`, `#`, link targets and code fences hidden,
/// list markers as bullets and task boxes as boxes.
///
/// [linkRecognizer] is asked for a recogniser for each web link's text;
/// the caller owns and disposes what it returns. [taskChip] replaces a
/// `nemo://task/<id>` link's text with a widget; without it the link is
/// drawn as ordinary link text.
TextSpan markdownSpan(
  String text,
  TextStyle base,
  ThemeData theme, {
  bool capHeadings = false,
  GestureRecognizer? Function(String url)? linkRecognizer,
  Widget Function(String taskId)? taskChip,
}) {
  final ranges = parseMarkdownRanges(text);
  final links = [
    for (final r in ranges)
      if (r.style == MdStyle.link) r,
  ];
  String? urlOf(MdRange link) =>
      _linkTarget.firstMatch(text.substring(link.end))?[1];

  // Characters dropped: the markers, and each fence line with its break.
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
  final children = <InlineSpan>[];
  for (var i = 0; i + 1 < sorted.length; i++) {
    final a = sorted[i];
    final b = sorted[i + 1];
    if (a == b || isHidden(a, b)) continue;
    final styles = {
      for (final r in ranges)
        if (r.start <= a && b <= r.end) r.style,
    };
    final link = styles.contains(MdStyle.link)
        ? links.firstWhere((r) => r.start <= a && b <= r.end)
        : null;
    final url = link == null ? null : urlOf(link);
    final taskId = url == null ? null : taskIdFromLink(url);
    if (taskId != null && taskChip != null) {
      // The whole link text is one chip, placed where the text starts.
      if (a == link!.start) {
        children.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: taskChip(taskId),
          ),
        );
      }
      continue;
    }
    var style = markdownStyle(styles, base, theme);
    if (capHeadings && (style.fontSize ?? 0) > maxSize) {
      style = style.copyWith(fontSize: maxSize);
    }
    var piece = text.substring(a, b);
    if (styles.contains(MdStyle.listMarker)) piece = _listMarker(piece);
    children.add(
      TextSpan(
        text: piece,
        style: style,
        recognizer: url != null && linkRecognizer != null
            ? linkRecognizer(url)
            : null,
      ),
    );
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
