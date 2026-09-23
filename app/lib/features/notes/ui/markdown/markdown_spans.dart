/// Where a note body's markdown is, as character ranges.
///
/// The editor paints these over the raw text rather than rendering a
/// document, so what is on screen is character-for-character what is
/// stored. That needs exact source offsets, which the `markdown` package's
/// AST does not keep -- hence this small parser. It covers the shapes the
/// toolbar can produce, line by line, and treats anything it does not
/// recognise as plain text.
library;

import 'package:meta/meta.dart';

enum MdStyle {
  h1,
  h2,
  h3,
  h4,
  h5,
  h6,
  bold,
  italic,
  strike,
  code,
  codeBlock,
  quote,
  link,
  marker,
  listMarker,
  taskDone,
}

/// [style] over `[start, end)`, in UTF-16 code units of the body.
@immutable
class MdRange {
  const MdRange(this.start, this.end, this.style);

  final int start;
  final int end;
  final MdStyle style;

  @override
  bool operator ==(Object other) =>
      other is MdRange &&
      other.start == start &&
      other.end == end &&
      other.style == style;

  @override
  int get hashCode => Object.hash(start, end, style);

  @override
  String toString() => 'MdRange($start, $end, $style)';
}

const List<MdStyle> _headings = [
  MdStyle.h1,
  MdStyle.h2,
  MdStyle.h3,
  MdStyle.h4,
  MdStyle.h5,
  MdStyle.h6,
];

final _fence = RegExp(r'^\s*```');
final _rule = RegExp(r'^\s*([-*_])(?:\s*\1){2,}\s*$');
final _heading = RegExp('^(#{1,6}) ');
final _quote = RegExp(r'^>\s?');
// A box may end the line with nothing after it (`- [x]`, no space).
final _task = RegExp(r'^(\s*)[-*+] \[([ xX])\](?: |$)');
final _list = RegExp(r'^(\s*)(?:[-*+]|\d+[.)]) ');

final _inlineCode = RegExp('`[^`]+`');
// One level of balanced parentheses in the URL, as in `Foo_(bar)`.
final _link = RegExp(r'\[([^\]]+)\]\((?:[^()\s]|\([^()\s]*\))+\)');
final _boldStars = RegExp(r'\*\*(?=\S)(.+?)(?<=\S)\*\*');
final _boldUnders = RegExp(r'(?<!\w)__(?=\S)(.+?)(?<=\S)__(?!\w)');
final _strike = RegExp(r'~~(?=\S)(.+?)(?<=\S)~~');
final _italicStar = RegExp(r'(?<!\*)\*(?=\S)([^*]+?)(?<=\S)\*(?!\*)');
final _italicUnder = RegExp(r'(?<![_\w])_(?=\S)([^_]+?)(?<=\S)_(?![_\w])');

/// Stands in for characters already claimed, so a later pattern cannot
/// match across them. Keeps every offset where it was.
const _mask = '\u0000';

List<MdRange> parseMarkdownRanges(String text) {
  final out = <MdRange>[];
  var offset = 0;
  int? fenceStart;
  for (final line in text.split('\n')) {
    final end = offset + line.length;
    if (_fence.hasMatch(line)) {
      if (fenceStart == null) {
        fenceStart = offset;
      } else {
        out.add(MdRange(fenceStart, end, MdStyle.codeBlock));
        fenceStart = null;
      }
    } else if (fenceStart == null) {
      _parseLine(line, offset, out);
    }
    offset = end + 1;
  }
  if (fenceStart != null) {
    out.add(MdRange(fenceStart, text.length, MdStyle.codeBlock));
  }
  return out;
}

void _parseLine(String line, int base, List<MdRange> out) {
  if (_rule.hasMatch(line)) {
    out.add(MdRange(base, base + line.length, MdStyle.marker));
    return;
  }
  var contentStart = 0;
  final heading = _heading.firstMatch(line);
  final quote = _quote.firstMatch(line);
  final task = _task.firstMatch(line);
  final list = _list.firstMatch(line);
  if (heading != null) {
    final style = _headings[heading.group(1)!.length - 1];
    out
      ..add(MdRange(base, base + line.length, style))
      ..add(MdRange(base, base + heading.end, MdStyle.marker));
    contentStart = heading.end;
  } else if (quote != null) {
    out
      ..add(MdRange(base, base + line.length, MdStyle.quote))
      ..add(MdRange(base, base + quote.end, MdStyle.marker));
    contentStart = quote.end;
  } else if (task != null) {
    final indent = task.group(1)!.length;
    out.add(MdRange(base + indent, base + task.end, MdStyle.listMarker));
    if (task.group(2) != ' ' && task.end < line.length) {
      out.add(MdRange(base + task.end, base + line.length, MdStyle.taskDone));
    }
    contentStart = task.end;
  } else if (list != null) {
    final indent = list.group(1)!.length;
    out.add(MdRange(base + indent, base + list.end, MdStyle.listMarker));
    contentStart = list.end;
  }
  _parseInline(line.substring(contentStart), base + contentStart, out);
}

void _parseInline(String source, int base, List<MdRange> out) {
  var s = source;

  String mask(String s, int start, int end) =>
      s.replaceRange(start, end, _mask * (end - start));

  // Code first: nothing inside backticks is markdown.
  for (final m in _inlineCode.allMatches(s)) {
    out
      ..add(MdRange(base + m.start, base + m.end, MdStyle.code))
      ..add(MdRange(base + m.start, base + m.start + 1, MdStyle.marker))
      ..add(MdRange(base + m.end - 1, base + m.end, MdStyle.marker));
    s = mask(s, m.start, m.end);
  }

  // Links next, masking the brackets and URL -- a URL is full of `_`.
  for (final m in _link.allMatches(s)) {
    final textStart = m.start + 1;
    final textEnd = textStart + m.group(1)!.length;
    out
      ..add(MdRange(base + m.start, base + textStart, MdStyle.marker))
      ..add(MdRange(base + textStart, base + textEnd, MdStyle.link))
      ..add(MdRange(base + textEnd, base + m.end, MdStyle.marker));
    s = mask(s, m.start, textStart);
    s = mask(s, textEnd, m.end);
  }

  // Delimited spans: style the inside, mark and mask the delimiters so
  // the italic pass cannot mistake `**` for two `*`. The inside is left
  // unmasked, which is what allows one level of nesting.
  void delimited(RegExp pattern, int width, MdStyle style) {
    for (final m in pattern.allMatches(s)) {
      final innerStart = m.start + width;
      final innerEnd = m.end - width;
      out
        ..add(MdRange(base + innerStart, base + innerEnd, style))
        ..add(MdRange(base + m.start, base + innerStart, MdStyle.marker))
        ..add(MdRange(base + innerEnd, base + m.end, MdStyle.marker));
    }
    for (final m in pattern.allMatches(s).toList()) {
      s = mask(s, m.start, m.start + width);
      s = mask(s, m.end - width, m.end);
    }
  }

  delimited(_boldStars, 2, MdStyle.bold);
  delimited(_boldUnders, 2, MdStyle.bold);
  delimited(_strike, 2, MdStyle.strike);
  delimited(_italicStar, 1, MdStyle.italic);
  delimited(_italicUnder, 1, MdStyle.italic);
}
