import 'package:flutter/services.dart';

/// The edits behind the note toolbar, its shortcuts and Enter in a list.
///
/// Each one maps a whole [TextEditingValue] to the next, so it lands as a
/// single change the field's undo takes back in one step, and can be
/// tested without a widget.

/// A value's selection, or a cursor at the end when the field has never
/// had one.
TextSelection _selection(TextEditingValue v) => v.selection.isValid
    ? v.selection
    : TextSelection.collapsed(offset: v.text.length);

/// Start and end of the lines `[start, end]` touches.
(int, int) _lineBounds(String text, int start, int end) {
  final lineStart = start == 0 ? 0 : text.lastIndexOf('\n', start - 1) + 1;
  final newline = text.indexOf('\n', end);
  return (lineStart, newline == -1 ? text.length : newline);
}

bool _isSpace(String c) => c == ' ' || c == '\t' || c == '\n';

TextEditingValue toggleInline(TextEditingValue v, String marker) {
  final sel = _selection(v);
  final t = v.text;
  final m = marker.length;
  var s = sel.start;
  var e = sel.end;
  while (s < e && _isSpace(t[s])) {
    s++;
  }
  while (e > s && _isSpace(t[e - 1])) {
    e--;
  }

  if (s >= m &&
      e + m <= t.length &&
      t.substring(s - m, s) == marker &&
      t.substring(e, e + m) == marker) {
    return TextEditingValue(
      text: t.replaceRange(e, e + m, '').replaceRange(s - m, s, ''),
      selection: TextSelection(baseOffset: s - m, extentOffset: e - m),
    );
  }

  final inner = t.substring(s, e);
  if (inner.length >= 2 * m &&
      inner.startsWith(marker) &&
      inner.endsWith(marker)) {
    final unwrapped = inner.substring(m, inner.length - m);
    return TextEditingValue(
      text: t.replaceRange(s, e, unwrapped),
      selection: TextSelection(
        baseOffset: s,
        extentOffset: s + unwrapped.length,
      ),
    );
  }

  return TextEditingValue(
    text: t.replaceRange(s, e, '$marker$inner$marker'),
    selection: s == e
        ? TextSelection.collapsed(offset: s + m)
        : TextSelection(baseOffset: s + m, extentOffset: e + m),
  );
}

/// Replaces each line the selection touches with `f(line)`. With one
/// line, the selection shifts with the edit; with several, blank lines
/// are left alone and the whole block ends up selected.
TextEditingValue _mapLines(TextEditingValue v, String Function(String line) f) {
  final sel = _selection(v);
  final t = v.text;
  final (ls, le) = _lineBounds(t, sel.start, sel.end);
  final lines = t.substring(ls, le).split('\n');
  final single = lines.length == 1;
  final mapped = <String>[
    for (final line in lines)
      if (!single && line.trim().isEmpty) line else f(line),
  ].join('\n');
  final text = t.replaceRange(ls, le, mapped);
  if (single) {
    final delta = mapped.length - (le - ls);
    int shift(int o) => (o + delta).clamp(ls, ls + mapped.length);
    return TextEditingValue(
      text: text,
      selection: TextSelection(
        baseOffset: shift(sel.baseOffset),
        extentOffset: shift(sel.extentOffset),
      ),
    );
  }
  return TextEditingValue(
    text: text,
    selection: TextSelection(baseOffset: ls, extentOffset: ls + mapped.length),
  );
}

/// The non-blank lines a selection touches, or the one line it sits on.
List<String> _touchedLines(TextEditingValue v) {
  final sel = _selection(v);
  final (ls, le) = _lineBounds(v.text, sel.start, sel.end);
  final lines = v.text.substring(ls, le).split('\n');
  if (lines.length == 1) return lines;
  return [
    for (final l in lines)
      if (l.trim().isNotEmpty) l,
  ];
}

final _anyBlockPrefix = RegExp(r'^(?:[-*+] \[[ xX]\] |[-*+] |\d+\. |> )');
final _numbered = RegExp(r'^\d+\. ');

TextEditingValue toggleLinePrefix(TextEditingValue v, String prefix) {
  final numbered = prefix == '1. ';
  final has = numbered ? _numbered : RegExp('^${RegExp.escape(prefix)}');
  final remove = _touchedLines(v).every(has.hasMatch);
  var n = 0;
  return _mapLines(v, (line) {
    if (remove) return line.replaceFirst(has, '');
    n++;
    final stripped = line.replaceFirst(_anyBlockPrefix, '');
    return '${numbered ? '$n. ' : prefix}$stripped';
  });
}

final _headingPrefix = RegExp('^(#{1,6}) ');

TextEditingValue cycleHeading(TextEditingValue v) {
  final sel = _selection(v);
  final collapsed = TextEditingValue(
    text: v.text,
    selection: TextSelection(
      baseOffset: sel.baseOffset,
      extentOffset: sel.baseOffset,
    ),
  );
  final result = _mapLines(collapsed, (line) {
    final m = _headingPrefix.firstMatch(line);
    final level = m == null ? 0 : m.group(1)!.length;
    final rest = m == null ? line : line.substring(m.end);
    return level >= 3 ? rest : '${'#' * (level + 1)} $rest';
  });
  return result;
}

final _openBox = RegExp(r'^(\s*[-*+]) \[ \] ');
final _checkedBox = RegExp(r'^(\s*[-*+]) \[[xX]\] ');
final _bullet = RegExp(r'^(\s*)[-*+] ');
final _number = RegExp(r'^(\s*)\d+\. ');

TextEditingValue toggleCheckbox(TextEditingValue v) => _mapLines(v, (line) {
  if (_openBox.hasMatch(line)) {
    return line.replaceFirstMapped(_openBox, (m) => '${m[1]} [x] ');
  }
  if (_checkedBox.hasMatch(line)) {
    return line.replaceFirstMapped(_checkedBox, (m) => '${m[1]} [ ] ');
  }
  if (_bullet.hasMatch(line)) {
    return line.replaceFirstMapped(_bullet, (m) => '${m[1]}- [ ] ');
  }
  if (_number.hasMatch(line)) {
    return line.replaceFirstMapped(_number, (m) => '${m[1]}- [ ] ');
  }
  return '- [ ] $line';
});

final _fenceLine = RegExp(r'^\s*```');

TextEditingValue toggleCodeBlock(TextEditingValue v) {
  final sel = _selection(v);
  final t = v.text;
  final lines = t.split('\n');
  final starts = <int>[];
  var offset = 0;
  for (final line in lines) {
    starts.add(offset);
    offset += line.length + 1;
  }
  final cursorLine = starts.lastIndexWhere((s) => s <= sel.start);

  // Inside a block: an odd number of fences above the cursor line, and a
  // closing one at or below it.
  final above = [
    for (var i = 0; i < cursorLine; i++)
      if (_fenceLine.hasMatch(lines[i])) i,
  ];
  if (above.length.isOdd && !_fenceLine.hasMatch(lines[cursorLine])) {
    final open = above.last;
    final close = [
      for (var i = cursorLine + 1; i < lines.length; i++)
        if (_fenceLine.hasMatch(lines[i])) i,
    ].firstOrNull;
    if (close != null) {
      final openLength = lines[open].length + 1;
      final kept = <String>[...lines]
        ..removeAt(close)
        ..removeAt(open);
      final text = kept.join('\n');
      return TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(
          offset: (sel.start - openLength).clamp(0, text.length),
        ),
      );
    }
  }

  final (ls, le) = _lineBounds(t, sel.start, sel.end);
  final block = t.substring(ls, le);
  return TextEditingValue(
    text: t.replaceRange(ls, le, '```\n$block\n```'),
    selection: block.isEmpty
        ? TextSelection.collapsed(offset: ls + 4)
        : TextSelection(
            baseOffset: ls + 4,
            extentOffset: ls + 4 + block.length,
          ),
  );
}

TextEditingValue insertLink(TextEditingValue v, String url) {
  final sel = _selection(v);
  final label = sel.isCollapsed ? url : sel.textInside(v.text);
  final link = '[$label]($url)';
  return TextEditingValue(
    text: v.text.replaceRange(sel.start, sel.end, link),
    selection: TextSelection.collapsed(offset: sel.start + link.length),
  );
}

final _listPrefix = RegExp(
  r'^(\s*)(?:([-*+]) \[[ xX]\] |([-*+]) |(\d+)([.)]) )',
);

/// What Enter does on a list line, or null when it should just insert a
/// newline. [v] is the value before the newline.
TextEditingValue? continueList(TextEditingValue v) {
  final sel = _selection(v);
  if (!sel.isCollapsed) return null;
  final t = v.text;
  final (ls, le) = _lineBounds(t, sel.start, sel.start);
  final line = t.substring(ls, le);
  final m = _listPrefix.firstMatch(line);
  if (m == null || sel.start - ls < m.end) return null;

  if (line.substring(m.end).trim().isEmpty) {
    return TextEditingValue(
      text: t.replaceRange(ls, le, ''),
      selection: TextSelection.collapsed(offset: ls),
    );
  }

  final indent = m[1]!;
  final String next;
  if (m[2] != null) {
    next = '$indent${m[2]} [ ] ';
  } else if (m[3] != null) {
    next = '$indent${m[3]} ';
  } else {
    next = '$indent${int.parse(m[4]!) + 1}${m[5]} ';
  }
  final insert = '\n$next';
  return TextEditingValue(
    text: t.replaceRange(sel.start, sel.start, insert),
    selection: TextSelection.collapsed(offset: sel.start + insert.length),
  );
}

final _linkPattern = RegExp(r'\[[^\]]+\]\(([^)\s]+)\)');

/// The URL of the link the cursor is in or touching, if any.
String? linkAtCursor(TextEditingValue v) {
  final sel = v.selection;
  if (!sel.isValid || !sel.isCollapsed) return null;
  final (ls, le) = _lineBounds(v.text, sel.start, sel.start);
  final line = v.text.substring(ls, le);
  final c = sel.start - ls;
  for (final m in _linkPattern.allMatches(line)) {
    if (m.start <= c && c <= m.end) return m[1];
  }
  return null;
}

/// Runs [continueList] when the only change is a newline typed at the
/// cursor. A formatter rather than a key handler, so soft keyboards and
/// IMEs get it too.
class ListContinuationFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final o = oldValue.selection;
    if (!o.isValid || !o.isCollapsed) return newValue;
    final at = o.baseOffset;
    if (newValue.text.length != oldValue.text.length + 1 ||
        !newValue.selection.isCollapsed ||
        newValue.selection.baseOffset != at + 1 ||
        newValue.text[at] != '\n' ||
        newValue.text.replaceRange(at, at + 1, '') != oldValue.text) {
      return newValue;
    }
    return continueList(oldValue) ?? newValue;
  }
}
