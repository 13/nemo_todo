/// A note body split into the lines the read view draws, each with its
/// place in the source so a tap can be mapped back to the text.
library;

import 'package:meta/meta.dart';

enum ReadKind {
  blank,
  text,
  heading,
  quote,
  bullet,
  numbered,
  task,
  rule,
  codeBlock,
}

@immutable
class ReadLine {
  const ReadLine({
    required this.start,
    required this.end,
    required this.kind,
    required this.contentStart,
    this.level = 0,
    this.checked = false,
    this.marker = '',
  });

  /// `[start, end)` of the whole line (a code block spans its fences).
  final int start;
  final int end;
  final ReadKind kind;

  /// Where the text after the block marker begins; for a code block, the
  /// first character after the opening fence's line break.
  final int contentStart;

  /// Heading level (1-6) for a heading; indent width for a list or task.
  final int level;

  /// A task line's box is ticked.
  final bool checked;

  /// A numbered line's number with its `.` or `)`, as written.
  final String marker;
}

final _fence = RegExp(r'^\s*```');
final _rule = RegExp(r'^\s*([-*_])(?:\s*\1){2,}\s*$');
final _heading = RegExp('^(#{1,6}) ');
final _quote = RegExp(r'^>\s?');
final _task = RegExp(r'^(\s*)[-*+] \[([ xX])\](?: |$)');
final _bullet = RegExp(r'^(\s*)[-*+] ');
final _numbered = RegExp(r'^(\s*)(\d+[.)]) ');

List<ReadLine> readLines(String body) {
  final out = <ReadLine>[];
  final lines = body.split('\n');
  var offset = 0;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final start = offset;
    final end = start + line.length;
    if (_fence.hasMatch(line)) {
      // Everything up to the closing fence, or the end of the body.
      var j = i + 1;
      var close = -1;
      var scan = end + 1;
      for (; j < lines.length; j++) {
        if (_fence.hasMatch(lines[j])) {
          close = scan;
          break;
        }
        scan += lines[j].length + 1;
      }
      final contentStart = end + 1 > body.length ? body.length : end + 1;
      if (close == -1) {
        out.add(
          ReadLine(
            start: start,
            end: body.length,
            kind: ReadKind.codeBlock,
            contentStart: contentStart,
          ),
        );
        break;
      }
      final closeEnd = close + lines[j].length;
      out.add(
        ReadLine(
          start: start,
          // The content's last line break is not part of the code.
          end: closeEnd,
          kind: ReadKind.codeBlock,
          contentStart: contentStart,
        ),
      );
      offset = closeEnd + 1;
      i = j;
      continue;
    }
    out.add(_classify(line, start, end));
    offset = end + 1;
  }
  return out;
}

ReadLine _classify(String line, int start, int end) {
  ReadLine at(
    ReadKind kind,
    int content, {
    int level = 0,
    bool checked = false,
    String marker = '',
  }) => ReadLine(
    start: start,
    end: end,
    kind: kind,
    contentStart: start + content,
    level: level,
    checked: checked,
    marker: marker,
  );
  if (line.trim().isEmpty) return at(ReadKind.blank, line.length);
  if (_rule.hasMatch(line)) return at(ReadKind.rule, line.length);
  if (_heading.firstMatch(line) case final m?) {
    return at(ReadKind.heading, m.end, level: m[1]!.length);
  }
  if (_quote.firstMatch(line) case final m?) return at(ReadKind.quote, m.end);
  if (_task.firstMatch(line) case final m?) {
    return at(ReadKind.task, m.end, level: m[1]!.length, checked: m[2] != ' ');
  }
  if (_bullet.firstMatch(line) case final m?) {
    return at(ReadKind.bullet, m.end, level: m[1]!.length);
  }
  if (_numbered.firstMatch(line) case final m?) {
    return at(ReadKind.numbered, m.end, level: m[1]!.length, marker: m[2]!);
  }
  return at(ReadKind.text, 0);
}

final _box = RegExp(r'\[([ xX])\]');

/// [body] with the box on the task line starting at [lineStart] flipped;
/// unchanged when that line is not a task.
String toggleTaskAt(String body, int lineStart) {
  final nl = body.indexOf('\n', lineStart);
  final lineEnd = nl == -1 ? body.length : nl;
  final line = body.substring(lineStart, lineEnd);
  final task = _task.firstMatch(line);
  if (task == null) return body;
  final box = _box.firstMatch(line)!;
  final flipped = box[1] == ' ' ? '[x]' : '[ ]';
  return body.replaceRange(lineStart + box.start, lineStart + box.end, flipped);
}
