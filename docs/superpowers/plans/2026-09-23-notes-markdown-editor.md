# Notes Markdown Editor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make a note's body always editable, styled as live markdown while typing, with a formatting toolbar above the keyboard.

**Architecture:** A pure-Dart parser turns the body into styled character ranges; a `TextEditingController` subclass paints those ranges in `buildTextSpan` without changing the text. Pure `TextEditingValue -> TextEditingValue` commands implement every toolbar button, shortcut and Enter-continues-list. `NoteDetailScreen` drops its read/edit toggle, uses the new controller, shows the toolbar while the body has focus, and saves on a 1 s debounce as well as on unfocus/pop.

**Tech Stack:** Flutter 3.47.2 (via fvm), Riverpod, go_router, gen-l10n. No new dependencies; `flutter_markdown_plus` is removed.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-09-23-notes-markdown-editor-design.md`.
- Flutter is not on PATH: prefix commands with `export PATH=$HOME/fvm/versions/3.47.2/bin:$PATH`. Run them from `app/`.
- UI only: no change to `Note`, the database, sync, server or export. `Note.body` stays the raw markdown string.
- The editor never rewrites text to style it. Markers stay in the text, drawn faint.
- New code lives in `app/lib/features/notes/ui/markdown/`; tests in `app/test/features/notes/markdown/`.
- Toolbar button keys: `md-bold`, `md-italic`, `md-strike`, `md-heading`, `md-bullet`, `md-numbered`, `md-checkbox`, `md-quote`, `md-code`, `md-code-block`, `md-link`, `md-open-link`, `md-undo`, `md-redo`. Existing keys `note-title`, `note-body` stay.
- Italic uses `_` from the toolbar (so it cannot collide with `**`); the parser accepts both `*` and `_`.
- Links open only for `http`/`https`, through `openUrlProvider` (`app/lib/features/settings/ui/about_tile.dart`).
- Debounce: 1 s after the last title or body change.
- Run at most one `flutter test` process at a time, with `--concurrency=2` for directories (shared machine, OOM risk). After a directory run, check the reported test count is non-zero and plausible.
- Commits end with the session's `Co-Authored-By` / `Claude-Session` trailer lines. The pre-commit hook regenerates generated sources (including `app_localizations*.dart`) and fails if they differ: run `flutter gen-l10n` and commit the regenerated files with their `.arb` sources. The hook needs `flutter` and `dart` on PATH.

---

### Task 1: Markdown range parser

**Files:**
- Create: `app/lib/features/notes/ui/markdown/markdown_spans.dart`
- Test: `app/test/features/notes/markdown/markdown_spans_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `enum MdStyle { h1, h2, h3, h4, h5, h6, bold, italic, strike, code, codeBlock, quote, link, marker, listMarker, taskDone }`
  - `class MdRange { const MdRange(int start, int end, MdStyle style); final int start; final int end; final MdStyle style; }` (UTF-16 offsets, `end` exclusive)
  - `List<MdRange> parseMarkdownRanges(String text)`

- [ ] **Step 1: Write the failing test**

`app/test/features/notes/markdown/markdown_spans_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/notes/ui/markdown/markdown_spans.dart';

/// Every style covering the character at [index] of [text].
Set<MdStyle> stylesAt(String text, int index) => {
  for (final r in parseMarkdownRanges(text))
    if (r.start <= index && index < r.end) r.style,
};

/// Styles at the first occurrence of [needle] in [text].
Set<MdStyle> stylesOf(String text, String needle) =>
    stylesAt(text, text.indexOf(needle));

void main() {
  group('headings', () {
    for (var level = 1; level <= 6; level++) {
      test('level $level styles the line and marks the hashes', () {
        final text = '${'#' * level} Title';
        final heading = MdStyle.values[level - 1];
        expect(stylesOf(text, 'Title'), {heading});
        expect(stylesAt(text, 0), {heading, MdStyle.marker});
      });
    }

    test('hashes without a space are plain text', () {
      expect(parseMarkdownRanges('#hashtag'), isEmpty);
    });
  });

  group('emphasis', () {
    test('bold with both spellings', () {
      expect(stylesOf('a **b** c', 'b'), {MdStyle.bold});
      expect(stylesOf('a __b__ c', 'b'), {MdStyle.bold});
      expect(stylesAt('a **b** c', 2), {MdStyle.marker});
    });

    test('italic with both spellings', () {
      expect(stylesOf('a *b* c', 'b'), {MdStyle.italic});
      expect(stylesOf('a _b_ c', 'b'), {MdStyle.italic});
      expect(stylesAt('a _b_ c', 2), {MdStyle.marker});
    });

    test('strike', () {
      expect(stylesOf('~~gone~~', 'gone'), {MdStyle.strike});
      expect(stylesAt('~~gone~~', 0), {MdStyle.marker});
    });

    test('italic nested one level inside bold', () {
      const text = '**bold *and italic***';
      expect(stylesOf(text, 'bold'), {MdStyle.bold});
      expect(stylesOf(text, 'and'), {MdStyle.bold, MdStyle.italic});
    });

    test('an unclosed delimiter stays plain', () {
      expect(parseMarkdownRanges('**never closed'), isEmpty);
      expect(parseMarkdownRanges('~~never closed'), isEmpty);
    });

    test('an underscore inside a word is not emphasis', () {
      expect(parseMarkdownRanges('snake_case_name'), isEmpty);
    });

    test('no inline span crosses a newline', () {
      expect(parseMarkdownRanges('**a\nb**'), isEmpty);
    });
  });

  group('inline code', () {
    test('is code and shields its contents', () {
      const text = 'run `a **b** c` now';
      expect(stylesOf(text, 'b'), {MdStyle.code});
      expect(stylesOf(text, 'now'), isEmpty);
    });
  });

  group('links', () {
    test('text is link, brackets and url are markers', () {
      const text = 'see [docs](https://x.y/a_b_c) ok';
      expect(stylesOf(text, 'docs'), {MdStyle.link});
      expect(stylesOf(text, '['), {MdStyle.marker});
      expect(stylesOf(text, 'https'), {MdStyle.marker});
      // Underscores in the URL are not italic.
      expect(stylesOf(text, 'b_c'), {MdStyle.marker});
      expect(stylesOf(text, 'ok'), isEmpty);
    });
  });

  group('blocks', () {
    test('quote styles the line and marks the >', () {
      expect(stylesOf('> said', 'said'), {MdStyle.quote});
      expect(stylesAt('> said', 0), {MdStyle.quote, MdStyle.marker});
    });

    test('bullets and numbers are list markers', () {
      expect(stylesAt('- milk', 0), {MdStyle.listMarker});
      expect(stylesAt('* milk', 0), {MdStyle.listMarker});
      expect(stylesAt('+ milk', 0), {MdStyle.listMarker});
      expect(stylesAt('12. milk', 1), {MdStyle.listMarker});
      expect(stylesOf('- milk', 'milk'), isEmpty);
    });

    test('an open task is a list marker, a checked one is done', () {
      expect(stylesOf('- [ ] bread', '['), {MdStyle.listMarker});
      expect(stylesOf('- [ ] bread', 'bread'), isEmpty);
      expect(stylesOf('- [x] bread', 'bread'), {MdStyle.taskDone});
      expect(stylesOf('- [X] bread', 'bread'), {MdStyle.taskDone});
    });

    test('inline styles work inside list items', () {
      expect(stylesOf('- **milk**', 'milk'), {MdStyle.bold});
    });

    test('a horizontal rule is a marker', () {
      expect(stylesAt('---', 1), {MdStyle.marker});
      expect(stylesAt('* * *', 2), {MdStyle.marker});
    });

    test('a fenced block is code, with no inline parsing inside', () {
      const text = 'a\n```\n**x**\n```\nb';
      expect(stylesOf(text, '**x'), {MdStyle.codeBlock});
      expect(stylesOf(text, '```'), {MdStyle.codeBlock});
      expect(stylesOf(text, 'b'), isEmpty);
    });

    test('an unclosed fence runs to the end', () {
      const text = '```\n**x**';
      expect(stylesAt(text, text.length - 1), {MdStyle.codeBlock});
    });
  });

  test('offsets are UTF-16 and stay right after emoji and umlauts', () {
    const text = '🍞 Brötchen **süß**';
    expect(stylesOf(text, 'süß'), {MdStyle.bold});
    expect(stylesAt(text, text.length - 1), {MdStyle.marker});
    expect(stylesOf(text, 'Brötchen'), isEmpty);
  });

  test('empty text has no ranges', () {
    expect(parseMarkdownRanges(''), isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/notes/markdown/markdown_spans_test.dart`
Expected: FAIL, compile error "Target of URI doesn't exist".

- [ ] **Step 3: Write the implementation**

`app/lib/features/notes/ui/markdown/markdown_spans.dart`:

```dart
/// Where a note body's markdown is, as character ranges.
///
/// The editor paints these over the raw text rather than rendering a
/// document, so what is on screen is character-for-character what is
/// stored. That needs exact source offsets, which the `markdown` package's
/// AST does not keep -- hence this small parser. It covers the shapes the
/// toolbar can produce, line by line, and treats anything it does not
/// recognise as plain text.
library;

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

const _headings = [
  MdStyle.h1,
  MdStyle.h2,
  MdStyle.h3,
  MdStyle.h4,
  MdStyle.h5,
  MdStyle.h6,
];

final _fence = RegExp(r'^\s*```');
final _rule = RegExp(r'^\s*([-*_])(?:\s*\1){2,}\s*$');
final _heading = RegExp(r'^(#{1,6}) ');
final _quote = RegExp(r'^>\s?');
final _task = RegExp(r'^(\s*)[-*+] \[([ xX])\] ');
final _list = RegExp(r'^(\s*)(?:[-*+]|\d+[.)]) ');

final _inlineCode = RegExp('`[^`]+`');
final _link = RegExp(r'\[([^\]]+)\]\([^)\s]+\)');
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
```

Note on the nesting test: in `**bold *and italic***` the bold pattern takes the first two of the closing three stars; after masking, the italic pattern matches `*and italic` up to the last star, with the two masked characters inside. Those characters also carry `marker`, which the painter lets win, so they still draw faint.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/notes/markdown/markdown_spans_test.dart`
Expected: PASS, all tests. If one fails, fix the parser, not the test -- the tests are the spec's rules.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/notes/ui/markdown/markdown_spans.dart app/test/features/notes/markdown/markdown_spans_test.dart
git commit -m "feat(app): parse a note body into markdown style ranges"
```

---

### Task 2: Editing commands

**Files:**
- Create: `app/lib/features/notes/ui/markdown/markdown_commands.dart`
- Test: `app/test/features/notes/markdown/markdown_commands_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces (all top-level in `markdown_commands.dart`):
  - `TextEditingValue toggleInline(TextEditingValue v, String marker)`
  - `TextEditingValue toggleLinePrefix(TextEditingValue v, String prefix)` — `prefix` is one of `'> '`, `'- '`, `'1. '`
  - `TextEditingValue cycleHeading(TextEditingValue v)`
  - `TextEditingValue toggleCheckbox(TextEditingValue v)`
  - `TextEditingValue toggleCodeBlock(TextEditingValue v)`
  - `TextEditingValue insertLink(TextEditingValue v, String url)`
  - `TextEditingValue? continueList(TextEditingValue v)`
  - `String? linkAtCursor(TextEditingValue v)`
  - `class ListContinuationFormatter extends TextInputFormatter`

- [ ] **Step 1: Write the failing test**

`app/test/features/notes/markdown/markdown_commands_test.dart`:

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/notes/ui/markdown/markdown_commands.dart';

/// Builds a value from text where `|` marks a collapsed cursor, or `[`
/// and `]` mark a selection. The markers are not part of the text.
TextEditingValue v(String marked) {
  final caret = marked.indexOf('|');
  if (caret >= 0) {
    return TextEditingValue(
      text: marked.replaceFirst('|', ''),
      selection: TextSelection.collapsed(offset: caret),
    );
  }
  final start = marked.indexOf('[');
  final end = marked.indexOf(']') - 1;
  return TextEditingValue(
    text: marked.replaceFirst('[', '').replaceFirst(']', ''),
    selection: TextSelection(baseOffset: start, extentOffset: end),
  );
}

/// The inverse of [v], for readable expectations.
String show(TextEditingValue value) {
  final s = value.selection;
  if (s.isCollapsed) {
    return value.text.replaceRange(s.start, s.start, '|');
  }
  return value.text
      .replaceRange(s.end, s.end, ']')
      .replaceRange(s.start, s.start, '[');
}

void main() {
  group('toggleInline', () {
    test('wraps a selection', () {
      expect(show(toggleInline(v('buy [milk] now'), '**')), 'buy **[milk]** now');
    });

    test('unwraps when the markers sit just outside', () {
      expect(show(toggleInline(v('buy **[milk]** now'), '**')), 'buy [milk] now');
    });

    test('unwraps when the markers are inside the selection', () {
      expect(show(toggleInline(v('buy [**milk**] now'), '**')), 'buy [milk] now');
    });

    test('a collapsed cursor inserts a pair and sits between', () {
      expect(show(toggleInline(v('a |b'), '~~')), 'a ~~|~~b');
    });

    test('a second toggle on an empty pair removes it', () {
      expect(show(toggleInline(v('a ~~|~~b'), '~~')), 'a |b');
    });

    test('surrounding spaces stay outside the markers', () {
      expect(show(toggleInline(v('a[ milk ]b'), '_')), 'a _[milk]_ b');
    });

    test('an invalid selection appends at the end', () {
      final value = toggleInline(const TextEditingValue(text: 'ab'), '`');
      expect(show(value), 'ab`|`');
    });
  });

  group('toggleLinePrefix', () {
    test('adds a bullet to the cursor line', () {
      expect(show(toggleLinePrefix(v('one\ntw|o'), '- ')), 'one\n- tw|o');
    });

    test('removes it when present', () {
      expect(show(toggleLinePrefix(v('- tw|o'), '- ')), 'tw|o');
    });

    test('prefixes every touched line, skipping blank ones', () {
      expect(
        show(toggleLinePrefix(v('[a\n\nb]'), '> ')),
        '[> a\n\n> b]',
      );
    });

    test('mixed lines get the prefix added, not toggled per line', () {
      expect(show(toggleLinePrefix(v('[- a\nb]'), '- ')), '[- a\n- b]');
    });

    test('numbers count up', () {
      expect(show(toggleLinePrefix(v('[a\nb\nc]'), '1. ')), '[1. a\n2. b\n3. c]');
    });

    test('numbered lines lose their numbers', () {
      expect(show(toggleLinePrefix(v('[1. a\n2. b]'), '1. ')), '[a\nb]');
    });

    test('switching kind replaces the old prefix', () {
      expect(show(toggleLinePrefix(v('- a|'), '1. ')), '1. a|');
    });
  });

  group('cycleHeading', () {
    test('none, #, ##, ###, none', () {
      var value = v('Tit|le');
      value = cycleHeading(value);
      expect(show(value), '# Tit|le');
      value = cycleHeading(value);
      expect(show(value), '## Tit|le');
      value = cycleHeading(value);
      expect(show(value), '### Tit|le');
      value = cycleHeading(value);
      expect(show(value), 'Tit|le');
    });

    test('only the cursor line changes', () {
      expect(show(cycleHeading(v('a\nb|\nc'))), 'a\n# b|\nc');
    });
  });

  group('toggleCheckbox', () {
    test('flips an open box', () {
      expect(show(toggleCheckbox(v('- [ ] br|ead'))), '- [x] br|ead');
    });

    test('flips a checked box back', () {
      expect(show(toggleCheckbox(v('- [X] br|ead'))), '- [ ] br|ead');
    });

    test('promotes a bullet', () {
      expect(show(toggleCheckbox(v('- br|ead'))), '- [ ] br|ead');
    });

    test('prefixes a plain line', () {
      expect(show(toggleCheckbox(v('br|ead'))), '- [ ] br|ead');
    });
  });

  group('toggleCodeBlock', () {
    test('wraps the touched lines in fences', () {
      expect(show(toggleCodeBlock(v('[a\nb]'))), '```\n[a\nb]\n```');
    });

    test('an empty line becomes an empty block with the cursor inside', () {
      expect(show(toggleCodeBlock(v('|'))), '```\n|\n```');
    });

    test('inside a block, removes its fences', () {
      expect(show(toggleCodeBlock(v('x\n```\nco|de\n```\ny'))), 'x\nco|de\ny');
    });
  });

  group('insertLink', () {
    test('wraps the selection', () {
      expect(
        show(insertLink(v('see [docs] now'), 'https://x.y')),
        'see [docs](https://x.y)| now',
      );
    });

    test('with no selection uses the url as text', () {
      expect(show(insertLink(v('|'), 'https://x.y')), '[https://x.y](https://x.y)|');
    });
  });

  group('continueList', () {
    test('continues a bullet', () {
      expect(show(continueList(v('- milk|'))!), '- milk\n- |');
    });

    test('increments a number', () {
      expect(show(continueList(v('9. milk|'))!), '9. milk\n10. |');
    });

    test('continues a task unchecked, keeping indent', () {
      expect(show(continueList(v('  - [x] milk|'))!), '  - [x] milk\n  - [ ] |');
    });

    test('splits a line at the cursor', () {
      expect(show(continueList(v('- mi|lk'))!), '- mi\n- |lk');
    });

    test('an empty item ends the list', () {
      expect(show(continueList(v('- a\n- |'))!), '- a\n|');
    });

    test('a plain line is not a list', () {
      expect(continueList(v('milk|')), isNull);
    });

    test('a cursor inside the prefix is not a continuation', () {
      expect(continueList(v('-| milk')), isNull);
    });
  });

  group('linkAtCursor', () {
    const text = 'a [b](https://x.y) c';
    TextEditingValue at(int offset) => TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );

    test('inside a link', () {
      expect(linkAtCursor(at(text.indexOf('b'))), 'https://x.y');
    });

    test('on either edge of a link', () {
      expect(linkAtCursor(at(text.indexOf('['))), 'https://x.y');
      expect(linkAtCursor(at(text.indexOf(')') + 1)), 'https://x.y');
    });

    test('outside a link', () {
      expect(linkAtCursor(at(0)), isNull);
      expect(linkAtCursor(at(text.length)), isNull);
    });
  });

  group('ListContinuationFormatter', () {
    final formatter = ListContinuationFormatter();

    test('turns a typed newline on a list line into a continuation', () {
      final result = formatter.formatEditUpdate(
        v('- milk|'),
        v('- milk\n|'),
      );
      expect(show(result), '- milk\n- |');
    });

    test('leaves other edits alone', () {
      final typed = v('- milkx|');
      expect(formatter.formatEditUpdate(v('- milk|'), typed), typed);
      final pasted = v('- milk\nbread|');
      expect(formatter.formatEditUpdate(v('- milk|'), pasted), pasted);
    });

    test('leaves a newline on a plain line alone', () {
      final next = v('milk\n|');
      expect(formatter.formatEditUpdate(v('milk|'), next), next);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/notes/markdown/markdown_commands_test.dart`
Expected: FAIL, compile error "Target of URI doesn't exist".

- [ ] **Step 3: Write the implementation**

`app/lib/features/notes/ui/markdown/markdown_commands.dart`:

```dart
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
TextEditingValue _mapLines(
  TextEditingValue v,
  String Function(String line) f,
) {
  final sel = _selection(v);
  final t = v.text;
  final (ls, le) = _lineBounds(t, sel.start, sel.end);
  final lines = t.substring(ls, le).split('\n');
  final single = lines.length == 1;
  final mapped = [
    for (final line in lines)
      !single && line.trim().isEmpty ? line : f(line),
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
  return [for (final l in lines) if (l.trim().isNotEmpty) l];
}

final _anyBlockPrefix = RegExp(r'^(?:[-*+] \[[ xX]\] |[-*+] |\d+\. |> )');
final _numbered = RegExp(r'^\d+\. ');

TextEditingValue toggleLinePrefix(TextEditingValue v, String prefix) {
  final numbered = prefix == '1. ';
  final has = numbered
      ? _numbered
      : RegExp('^${RegExp.escape(prefix)}');
  final remove = _touchedLines(v).every(has.hasMatch);
  var n = 0;
  return _mapLines(v, (line) {
    if (remove) return line.replaceFirst(has, '');
    n++;
    final stripped = line.replaceFirst(_anyBlockPrefix, '');
    return '${numbered ? '$n. ' : prefix}$stripped';
  });
}

final _headingPrefix = RegExp(r'^(#{1,6}) ');

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
      final kept = [...lines]
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
        : TextSelection(baseOffset: ls + 4, extentOffset: ls + 4 + block.length),
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/notes/markdown/markdown_commands_test.dart`
Expected: PASS, all tests.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/notes/ui/markdown/markdown_commands.dart app/test/features/notes/markdown/markdown_commands_test.dart
git commit -m "feat(app): markdown edit commands for the note editor"
```

---

### Task 3: Live-styling controller

**Files:**
- Create: `app/lib/features/notes/ui/markdown/markdown_editing_controller.dart`
- Test: `app/test/features/notes/markdown/markdown_editing_controller_test.dart`

**Interfaces:**
- Consumes: `parseMarkdownRanges`, `MdStyle`, `MdRange` (Task 1).
- Produces:
  - `class MarkdownEditingController extends TextEditingController` with `MarkdownEditingController({String? text})`.
  - `TextStyle markdownStyle(Set<MdStyle> styles, TextStyle base, ThemeData theme)`.

- [ ] **Step 1: Write the failing test**

`app/test/features/notes/markdown/markdown_editing_controller_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/notes/ui/markdown/markdown_editing_controller.dart';
import 'package:nemo/features/notes/ui/markdown/markdown_spans.dart';

void main() {
  Future<TextSpan> build(
    WidgetTester tester,
    MarkdownEditingController controller, {
    bool withComposing = false,
  }) async {
    late TextSpan span;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            span = controller.buildTextSpan(
              context: context,
              style: const TextStyle(fontSize: 14),
              withComposing: withComposing,
            );
            return const SizedBox();
          },
        ),
      ),
    );
    return span;
  }

  List<TextSpan> leaves(TextSpan root) {
    final out = <TextSpan>[];
    root.visitChildren((s) {
      if (s is TextSpan && s.text != null) out.add(s);
      return true;
    });
    return out;
  }

  TextSpan leafWith(TextSpan root, String text) =>
      leaves(root).firstWhere((s) => s.text == text);

  testWidgets('painted text is exactly the stored text', (tester) async {
    const body = '# Title\n- [x] **done** ~~old~~ `c`\n> q [l](https://x.y)';
    final span = await build(
      tester,
      MarkdownEditingController(text: body),
    );
    expect(span.toPlainText(), body);
  });

  testWidgets('bold is bold and its markers are faint', (tester) async {
    final span = await build(
      tester,
      MarkdownEditingController(text: 'a **b** c'),
    );
    expect(leafWith(span, 'b').style!.fontWeight, FontWeight.w700);
    final marker = leafWith(span, '**').style!.color!;
    expect(marker.a, lessThan(1));
  });

  testWidgets('strike and done tasks are struck through', (tester) async {
    final span = await build(
      tester,
      MarkdownEditingController(text: '~~a~~\n- [x] b'),
    );
    expect(
      leafWith(span, 'a').style!.decoration!.contains(TextDecoration.lineThrough),
      isTrue,
    );
    expect(
      leafWith(span, 'b').style!.decoration!.contains(TextDecoration.lineThrough),
      isTrue,
    );
  });

  testWidgets('a heading is larger than body text', (tester) async {
    final span = await build(
      tester,
      MarkdownEditingController(text: '# Big'),
    );
    expect(leafWith(span, 'Big').style!.fontSize, greaterThan(14));
  });

  testWidgets('the composing range is underlined on top of the style', (
    tester,
  ) async {
    final controller = MarkdownEditingController(text: '**ab**')
      ..value = const TextEditingValue(
        text: '**ab**',
        selection: TextSelection.collapsed(offset: 4),
        composing: TextRange(start: 2, end: 4),
      );
    final span = await build(tester, controller, withComposing: true);
    final style = leafWith(span, 'ab').style!;
    expect(style.fontWeight, FontWeight.w700);
    expect(style.decoration!.contains(TextDecoration.underline), isTrue);
  });

  testWidgets('empty text builds an empty span', (tester) async {
    final span = await build(tester, MarkdownEditingController());
    expect(span.toPlainText(), '');
  });

  test('marker wins over other colours', () {
    final theme = ThemeData();
    final style = markdownStyle(
      {MdStyle.link, MdStyle.marker},
      const TextStyle(),
      theme,
    );
    expect(style.color, isNot(theme.colorScheme.primary));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/notes/markdown/markdown_editing_controller_test.dart`
Expected: FAIL, compile error "Target of URI doesn't exist".

- [ ] **Step 3: Write the implementation**

`app/lib/features/notes/ui/markdown/markdown_editing_controller.dart`:

```dart
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
            ?piece.decoration,
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
TextStyle markdownStyle(
  Set<MdStyle> styles,
  TextStyle base,
  ThemeData theme,
) {
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
```

If the analyzer rejects the `?piece.decoration` null-aware element (Dart 3.8+), replace with `if (piece.decoration != null) piece.decoration!`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/notes/markdown/markdown_editing_controller_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/notes/ui/markdown/markdown_editing_controller.dart app/test/features/notes/markdown/markdown_editing_controller_test.dart
git commit -m "feat(app): paint a note body's markdown as it is typed"
```

---

### Task 4: Formatting toolbar and its strings

**Files:**
- Create: `app/lib/features/notes/ui/markdown/note_format_toolbar.dart`
- Modify: `app/lib/l10n/app_en.arb`, `app/lib/l10n/app_de.arb`, `app/lib/l10n/app_it.arb` (add keys after `"notesDeleted"`)
- Regenerate: `app/lib/l10n/app_localizations*.dart` via `flutter gen-l10n`
- Test: `app/test/features/notes/markdown/note_format_toolbar_test.dart`

**Interfaces:**
- Consumes: every command from Task 2; `openUrlProvider` from `package:nemo/features/settings/ui/about_tile.dart`.
- Produces:
  - `class NoteFormatToolbar extends ConsumerWidget` — `NoteFormatToolbar({required TextEditingController controller, required UndoHistoryController undoController, Key? key})`.
  - `Future<void> promptForLink(BuildContext context, TextEditingController controller)` — asks for a URL and inserts it; used by the toolbar and by the Ctrl+K shortcut in Task 5.
  - `bool isWebLink(String url)` — true for parseable `http`/`https` URLs.
  - l10n getters `L.mdBold` … `L.mdRedo` (table below).

- [ ] **Step 1: Add strings**

Append to `app/lib/l10n/app_en.arb` (after `"notesDeleted": "Note deleted"`, adding a comma to that line):

```json
  "mdBold": "Bold",
  "mdItalic": "Italic",
  "mdStrike": "Strikethrough",
  "mdHeading": "Heading",
  "mdBulletList": "Bulleted list",
  "mdNumberedList": "Numbered list",
  "mdChecklist": "Checkbox",
  "mdQuote": "Quote",
  "mdCode": "Code",
  "mdCodeBlock": "Code block",
  "mdLink": "Link",
  "mdLinkUrlHint": "URL",
  "mdOpenLink": "Open link",
  "mdUndo": "Undo",
  "mdRedo": "Redo"
```

`app/lib/l10n/app_de.arb`, same position:

```json
  "mdBold": "Fett",
  "mdItalic": "Kursiv",
  "mdStrike": "Durchgestrichen",
  "mdHeading": "Überschrift",
  "mdBulletList": "Aufzählung",
  "mdNumberedList": "Nummerierte Liste",
  "mdChecklist": "Kontrollkästchen",
  "mdQuote": "Zitat",
  "mdCode": "Code",
  "mdCodeBlock": "Codeblock",
  "mdLink": "Link",
  "mdLinkUrlHint": "URL",
  "mdOpenLink": "Link öffnen",
  "mdUndo": "Rückgängig",
  "mdRedo": "Wiederholen"
```

`app/lib/l10n/app_it.arb`, same position:

```json
  "mdBold": "Grassetto",
  "mdItalic": "Corsivo",
  "mdStrike": "Barrato",
  "mdHeading": "Titolo",
  "mdBulletList": "Elenco puntato",
  "mdNumberedList": "Elenco numerato",
  "mdChecklist": "Casella di controllo",
  "mdQuote": "Citazione",
  "mdCode": "Codice",
  "mdCodeBlock": "Blocco di codice",
  "mdLink": "Link",
  "mdLinkUrlHint": "URL",
  "mdOpenLink": "Apri link",
  "mdUndo": "Annulla",
  "mdRedo": "Ripeti"
```

Check whether `"notesDeleted"` is the last key in each file (`tail -3 app/lib/l10n/app_*.arb`); if not, insert the block after it with correct commas. Then run `flutter gen-l10n`. Expected: no output, no errors.

- [ ] **Step 2: Write the failing test**

`app/test/features/notes/markdown/note_format_toolbar_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/notes/ui/markdown/markdown_editing_controller.dart';
import 'package:nemo/features/notes/ui/markdown/note_format_toolbar.dart';
import 'package:nemo/features/settings/ui/about_tile.dart' show openUrlProvider;
import 'package:nemo/l10n/app_localizations.dart';

void main() {
  late MarkdownEditingController controller;
  late UndoHistoryController undo;
  late List<Uri> opened;

  Future<void> pump(WidgetTester tester, TextEditingValue value) async {
    controller = MarkdownEditingController()..value = value;
    undo = UndoHistoryController();
    opened = [];
    addTearDown(controller.dispose);
    addTearDown(undo.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          openUrlProvider.overrideWithValue((uri) async {
            opened.add(uri);
            return true;
          }),
        ],
        child: MaterialApp(
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          home: Scaffold(
            body: Column(
              children: [
                TextField(controller: controller, undoController: undo),
                NoteFormatToolbar(
                  controller: controller,
                  undoController: undo,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  TextEditingValue sel(String text, int start, int end) => TextEditingValue(
    text: text,
    selection: TextSelection(baseOffset: start, extentOffset: end),
  );

  TextEditingValue at(String text, int offset) => TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: offset),
  );

  final cases = <String, (TextEditingValue, String)>{
    'md-bold': (sel('milk', 0, 4), '**milk**'),
    'md-italic': (sel('milk', 0, 4), '_milk_'),
    'md-strike': (sel('milk', 0, 4), '~~milk~~'),
    'md-code': (sel('milk', 0, 4), '`milk`'),
    'md-heading': (at('milk', 0), '# milk'),
    'md-bullet': (at('milk', 0), '- milk'),
    'md-numbered': (at('milk', 0), '1. milk'),
    'md-checkbox': (at('milk', 0), '- [ ] milk'),
    'md-quote': (at('milk', 0), '> milk'),
    'md-code-block': (at('milk', 0), '```\nmilk\n```'),
  };
  for (final MapEntry(key: key, value: (start, expected)) in cases.entries) {
    testWidgets('$key edits the text', (tester) async {
      await pump(tester, start);
      await tester.tap(find.byKey(Key(key)));
      await tester.pump();
      expect(controller.text, expected);
    });
  }

  testWidgets('link asks for a URL and wraps the selection', (tester) async {
    await pump(tester, sel('docs', 0, 4));
    await tester.tap(find.byKey(const Key('md-link')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('md-link-url')),
      'https://x.y',
    );
    await tester.tap(find.byKey(const Key('md-link-ok')));
    await tester.pumpAndSettle();
    expect(controller.text, '[docs](https://x.y)');
  });

  testWidgets('cancelling the link dialog changes nothing', (tester) async {
    await pump(tester, sel('docs', 0, 4));
    await tester.tap(find.byKey(const Key('md-link')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('md-link-cancel')));
    await tester.pumpAndSettle();
    expect(controller.text, 'docs');
  });

  testWidgets('open link shows only in a web link and opens it', (
    tester,
  ) async {
    const text = '[a](https://x.y) [b](javascript:alert(1))';
    // End of text touches the javascript link, which must not qualify.
    await pump(tester, at(text, text.length));
    expect(find.byKey(const Key('md-open-link')), findsNothing);

    controller.selection = const TextSelection.collapsed(offset: 1);
    await tester.pump();
    await tester.tap(find.byKey(const Key('md-open-link')));
    expect(opened, [Uri.parse('https://x.y')]);

    controller.selection = TextSelection.collapsed(
      offset: text.indexOf('b]'),
    );
    await tester.pump();
    expect(find.byKey(const Key('md-open-link')), findsNothing);
  });

  test('isWebLink', () {
    expect(isWebLink('https://x.y'), isTrue);
    expect(isWebLink('http://x.y'), isTrue);
    expect(isWebLink('javascript:alert(1)'), isFalse);
    expect(isWebLink('file:///etc/passwd'), isFalse);
    expect(isWebLink('mailto:a@b.c'), isFalse);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/features/notes/markdown/note_format_toolbar_test.dart`
Expected: FAIL, compile error "Target of URI doesn't exist".

- [ ] **Step 4: Write the implementation**

`app/lib/features/notes/ui/markdown/note_format_toolbar.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/features/notes/ui/markdown/markdown_commands.dart';
import 'package:nemo/features/settings/ui/about_tile.dart' show openUrlProvider;
import 'package:nemo/l10n/app_localizations.dart';

/// Whether a note may open [url]: web links only, so a note never quietly
/// opens `file:`, `mailto:` or `javascript:` -- the same rule the rendered
/// view used to apply.
bool isWebLink(String url) {
  final uri = Uri.tryParse(url);
  return uri != null && (uri.isScheme('http') || uri.isScheme('https'));
}

/// Asks for a URL and links the selection to it. Cancelling changes
/// nothing. The dialog takes focus from the body; the controller keeps
/// its selection, so the insert still lands where it was.
Future<void> promptForLink(
  BuildContext context,
  TextEditingController controller,
) async {
  final l = L.of(context);
  final field = TextEditingController();
  final url = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.mdLink),
      content: TextField(
        key: const Key('md-link-url'),
        controller: field,
        autofocus: true,
        keyboardType: TextInputType.url,
        decoration: InputDecoration(hintText: l.mdLinkUrlHint),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          key: const Key('md-link-cancel'),
          onPressed: () => Navigator.pop(context),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          key: const Key('md-link-ok'),
          onPressed: () => Navigator.pop(context, field.text),
          child: Text(l.mdLink),
        ),
      ],
    ),
  );
  field.dispose();
  final trimmed = url?.trim() ?? '';
  if (trimmed.isEmpty) return;
  controller.value = insertLink(controller.value, trimmed);
}

/// Formatting buttons for a note body, shown above the keyboard while the
/// body has focus. Every button is one [TextEditingValue] edit, so the
/// field's undo takes it back in one step.
class NoteFormatToolbar extends ConsumerWidget {
  const NoteFormatToolbar({
    required this.controller,
    required this.undoController,
    super.key,
  });

  final TextEditingController controller;
  final UndoHistoryController undoController;

  void _apply(TextEditingValue Function(TextEditingValue) command) {
    controller.value = command(controller.value);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final theme = Theme.of(context);

    Widget button(
      String key,
      IconData icon,
      String tooltip,
      VoidCallback? onPressed,
    ) => IconButton(
      key: Key(key),
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: onPressed,
    );

    // A click here is part of editing the body, not a tap outside it: on
    // web and desktop a mouse click outside a field unfocuses it, which
    // would hide this bar mid-click.
    return TextFieldTapRegion(
      child: Material(
        color: theme.colorScheme.surfaceContainer,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 48,
            child: ListenableBuilder(
              listenable: Listenable.merge([controller, undoController]),
              builder: (context, _) {
                final link = linkAtCursor(controller.value);
                final undo = undoController.value;
                return ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  children: [
                    button('md-undo', Icons.undo, l.mdUndo,
                        undo.canUndo ? undoController.undo : null),
                    button('md-redo', Icons.redo, l.mdRedo,
                        undo.canRedo ? undoController.redo : null),
                    button('md-bold', Icons.format_bold, l.mdBold,
                        () => _apply((v) => toggleInline(v, '**'))),
                    button('md-italic', Icons.format_italic, l.mdItalic,
                        () => _apply((v) => toggleInline(v, '_'))),
                    button('md-strike', Icons.format_strikethrough,
                        l.mdStrike, () => _apply((v) => toggleInline(v, '~~'))),
                    button('md-heading', Icons.title, l.mdHeading,
                        () => _apply(cycleHeading)),
                    button('md-bullet', Icons.format_list_bulleted,
                        l.mdBulletList,
                        () => _apply((v) => toggleLinePrefix(v, '- '))),
                    button('md-numbered', Icons.format_list_numbered,
                        l.mdNumberedList,
                        () => _apply((v) => toggleLinePrefix(v, '1. '))),
                    button('md-checkbox', Icons.check_box_outlined,
                        l.mdChecklist, () => _apply(toggleCheckbox)),
                    button('md-quote', Icons.format_quote, l.mdQuote,
                        () => _apply((v) => toggleLinePrefix(v, '> '))),
                    button('md-code', Icons.code, l.mdCode,
                        () => _apply((v) => toggleInline(v, '`'))),
                    button('md-code-block', Icons.data_object,
                        l.mdCodeBlock, () => _apply(toggleCodeBlock)),
                    button('md-link', Icons.link, l.mdLink,
                        () => unawaited(promptForLink(context, controller))),
                    if (link != null && isWebLink(link))
                      button('md-open-link', Icons.open_in_new, l.mdOpenLink,
                          () => unawaited(
                                ref.read(openUrlProvider)(Uri.parse(link)),
                              )),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
```

Run `dart format lib/features/notes/ui/markdown/note_format_toolbar.dart` after writing -- the button list above is not in formatter layout.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/notes/markdown/note_format_toolbar_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/notes/ui/markdown/note_format_toolbar.dart app/test/features/notes/markdown/note_format_toolbar_test.dart app/lib/l10n/
git commit -m "feat(app): a formatting toolbar for note bodies"
```

---

### Task 5: Always-editable note body

**Files:**
- Modify: `app/lib/features/notes/ui/note_detail_screen.dart` (whole file, below)
- Modify: `app/test/features/notes/note_detail_screen_test.dart` (replace first test, add new ones)

**Interfaces:**
- Consumes: `MarkdownEditingController` (Task 3); `ListContinuationFormatter`, `toggleInline` (Task 2); `NoteFormatToolbar`, `promptForLink` (Task 4).
- Produces: `NoteDetailScreen` with no `note-edit-toggle`; body `TextField` keyed `note-body` always present, its controller a `MarkdownEditingController`.

- [ ] **Step 1: Write the failing tests**

In `app/test/features/notes/note_detail_screen_test.dart`, add imports:

```dart
import 'package:flutter/services.dart';
import 'package:nemo/features/notes/ui/markdown/markdown_editing_controller.dart';
import 'package:nemo/features/settings/ui/about_tile.dart' show openUrlProvider;
```

Replace the first test (`'the body renders as markdown and edits as its source'`) with these, and keep every other existing test unchanged:

```dart
  TextField bodyField(WidgetTester tester) =>
      tester.widget<TextField>(find.byKey(const Key('note-body')));

  appTest('the body is editable markdown source with no toggle', (
    tester,
  ) async {
    final harness = await pumpApp(tester, initialLocation: '/notes/n1');
    await harness.seedList('l1', 'Kitchen');
    await harness.seedNote('n1', 'l1', title: 'Bread', body: '# Dough');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('note-edit-toggle')), findsNothing);
    final field = bodyField(tester);
    expect(field.controller, isA<MarkdownEditingController>());
    expect(field.controller!.text, '# Dough');
  });

  appTest('the toolbar shows only while the body has focus', (tester) async {
    final harness = await pumpApp(tester, initialLocation: '/notes/n1');
    await harness.seedList('l1', 'Kitchen');
    await harness.seedNote('n1', 'l1', title: 'Bread', body: 'milk');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('md-bold')), findsNothing);

    await tester.tap(find.byKey(const Key('note-body')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('md-bold')), findsOneWidget);

    await tester.tap(find.byKey(const Key('note-title')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('md-bold')), findsNothing);
  });

  appTest('bold wraps the selection and keeps the body focused', (
    tester,
  ) async {
    final harness = await pumpApp(tester, initialLocation: '/notes/n1');
    await harness.seedList('l1', 'Kitchen');
    await harness.seedNote('n1', 'l1', title: 'Bread', body: 'milk');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('note-body')));
    await tester.pumpAndSettle();
    bodyField(tester).controller!.selection = const TextSelection(
      baseOffset: 0,
      extentOffset: 4,
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('md-bold')));
    await tester.pump();

    expect(bodyField(tester).controller!.text, '**milk**');
    expect(bodyField(tester).focusNode!.hasFocus, isTrue);
  });

  appTest('ctrl+B bolds the selection', (tester) async {
    final harness = await pumpApp(tester, initialLocation: '/notes/n1');
    await harness.seedList('l1', 'Kitchen');
    await harness.seedNote('n1', 'l1', title: 'Bread', body: 'milk');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('note-body')));
    await tester.pumpAndSettle();
    bodyField(tester).controller!.selection = const TextSelection(
      baseOffset: 0,
      extentOffset: 4,
    );
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();

    expect(bodyField(tester).controller!.text, '**milk**');
  });

  appTest('enter on a list line continues the list', (tester) async {
    final harness = await pumpApp(tester, initialLocation: '/notes/n1');
    await harness.seedList('l1', 'Kitchen');
    await harness.seedNote('n1', 'l1', title: 'Bread');
    await tester.pumpAndSettle();

    final body = find.byKey(const Key('note-body'));
    await tester.enterText(body, '- milk');
    await tester.enterText(body, '- milk\n');
    await tester.pump();

    expect(bodyField(tester).controller!.text, '- milk\n- ');
  });

  appTest('typing saves after a pause without leaving the field', (
    tester,
  ) async {
    final harness = await pumpApp(tester, initialLocation: '/notes/n1');
    await harness.seedList('l1', 'Kitchen');
    await harness.seedNote('n1', 'l1', title: 'Bread');
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('note-body')), 'flour');
    await tester.pump(const Duration(milliseconds: 500));
    expect((await harness.db.noteById('n1'))!.body, '');

    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect((await harness.db.noteById('n1'))!.body, 'flour');
    expect(bodyField(tester).focusNode!.hasFocus, isTrue);
  });

  appTest('a sync arriving while typing does not replace the text', (
    tester,
  ) async {
    final harness = await pumpApp(tester, initialLocation: '/notes/n1');
    await harness.seedList('l1', 'Kitchen');
    await harness.seedNote('n1', 'l1', title: 'Bread');
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('note-body')), 'local');
    final stored = (await harness.db.noteById('n1'))!;
    await harness.container
        .read(notesRepositoryProvider)
        .save(stored.copyWith(body: 'remote'));
    await tester.pump();

    expect(bodyField(tester).controller!.text, 'local');
  });

  appTest('open link opens a web link at the cursor', (tester) async {
    final opened = <Uri>[];
    final harness = await pumpApp(
      tester,
      initialLocation: '/notes/n1',
      overrides: [
        openUrlProvider.overrideWithValue((uri) async {
          opened.add(uri);
          return true;
        }),
      ],
    );
    await harness.seedList('l1', 'Kitchen');
    await harness.seedNote(
      'n1',
      'l1',
      title: 'Bread',
      body: '[recipe](https://x.y)',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('note-body')));
    await tester.pumpAndSettle();
    bodyField(tester).controller!.selection = const TextSelection.collapsed(
      offset: 2,
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('md-open-link')));
    await tester.pump();

    expect(opened, [Uri.parse('https://x.y')]);
  });
```

If `seedNote` does not take a `body:` named argument, check `app/test/support/pump_app.dart` -- the existing first test already passes `body:`, so it does.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/notes/note_detail_screen_test.dart`
Expected: the new tests FAIL (controller is a plain `TextEditingController`, no toolbar, body absent until toggled); the kept tests still pass.

- [ ] **Step 3: Rewrite the screen**

Replace `app/lib/features/notes/ui/note_detail_screen.dart` with:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/core/widgets/max_width.dart';
import 'package:nemo/features/notes/ui/markdown/markdown_commands.dart';
import 'package:nemo/features/notes/ui/markdown/markdown_editing_controller.dart';
import 'package:nemo/features/notes/ui/markdown/note_format_toolbar.dart';
import 'package:nemo/features/notes/ui/note_editor_sections.dart';
import 'package:nemo/features/notes/ui/notes_providers.dart';
import 'package:nemo/features/photos/ui/photo_strip.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/router.dart';
import 'package:nemo_core/nemo_core.dart';

/// Title and body of one note. A note always opens as a page -- unlike a
/// task it never sits in the wide-window detail pane -- so there is no
/// `embedded` flag to plumb through here.
class NoteDetailScreen extends ConsumerStatefulWidget {
  const NoteDetailScreen({required this.noteId, super.key});

  final String noteId;

  @override
  ConsumerState<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends ConsumerState<NoteDetailScreen> {
  final _title = TextEditingController();
  final _body = MarkdownEditingController();
  final _undo = UndoHistoryController();
  final _titleFocus = FocusNode();
  final _bodyFocus = FocusNode();

  // There is no "Done" to mark the end of an edit any more, so a pause in
  // typing saves as well as leaving the field does.
  Timer? _debounce;
  static const _debounceDelay = Duration(seconds: 1);

  @override
  void initState() {
    super.initState();
    _titleFocus.addListener(_saveIfUnfocused);
    _bodyFocus.addListener(_saveIfUnfocused);
    // A listener, not `onChanged`: toolbar buttons and shortcuts write
    // `_body.value` directly, which `onChanged` never hears about.
    _body.addListener(_onBodyChanged);
  }

  String _lastBody = '';

  void _onBodyChanged() {
    if (_body.text == _lastBody) return; // selection-only change
    _lastBody = _body.text;
    // `_fill` writes only while unfocused, so a sync landing is not
    // mistaken for typing.
    if (_bodyFocus.hasFocus) _scheduleSave();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _title.dispose();
    _body.dispose();
    _undo.dispose();
    _titleFocus.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  /// Keeps the controllers in step with the stored note unless being
  /// edited. Never while a field has focus: an arriving sync would
  /// otherwise move the cursor out from under whoever is typing.
  void _fill(Note note) {
    if (!_titleFocus.hasFocus && _title.text != note.title) {
      _title.text = note.title;
    }
    if (!_bodyFocus.hasFocus && _body.text != note.body) {
      _body.text = note.body;
    }
  }

  void _scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () => unawaited(_save()));
  }

  void _saveIfUnfocused() {
    if (_titleFocus.hasFocus || _bodyFocus.hasFocus) return;
    unawaited(_save());
  }

  Future<void> _save() async {
    _debounce?.cancel();
    final note = ref.read(noteByIdProvider(widget.noteId)).value;
    if (note == null) return;
    final title = _title.text.trim();
    final body = _body.text;
    if ((title.isEmpty || title == note.title) && body == note.body) return;
    await ref
        .read(notesRepositoryProvider)
        .save(
          note.copyWith(title: title.isEmpty ? note.title : title, body: body),
        );
  }

  void _apply(TextEditingValue Function(TextEditingValue) command) {
    _body.value = command(_body.value);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final note = ref.watch(noteByIdProvider(widget.noteId)).value;
    if (note == null) {
      // A note can be deleted on another device while this page is open.
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(l.noteNotFound)),
      );
    }
    _fill(note);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _save();
        if (!context.mounted) return;
        // Reached directly -- a deep link, a shared URL, a PWA restore --
        // this can be the only page on the stack, with nothing below it
        // to pop back to.
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(Routes.notes);
        }
      },
      child: Scaffold(
        appBar: AppBar(actions: [NotePinAction(note: note)]),
        // The toolbar sits in the body, under the scrolling content: the
        // body is what the keyboard shrinks, so the bar rides directly on
        // top of it. `bottomNavigationBar` would stay behind the keyboard.
        body: Column(
          children: [
            Expanded(
              child: MaxWidth(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  children: [
                    TextField(
                      key: const Key('note-title'),
                      controller: _title,
                      focusNode: _titleFocus,
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => _scheduleSave(),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        hintText: l.noteTitleHint,
                        filled: false,
                        border: InputBorder.none,
                      ),
                    ),
                    CallbackShortcuts(
                      bindings: {
                        for (final meta in [false, true]) ...{
                          SingleActivator(
                            LogicalKeyboardKey.keyB,
                            control: !meta,
                            meta: meta,
                          ): () => _apply((v) => toggleInline(v, '**')),
                          SingleActivator(
                            LogicalKeyboardKey.keyI,
                            control: !meta,
                            meta: meta,
                          ): () => _apply((v) => toggleInline(v, '_')),
                          SingleActivator(
                            LogicalKeyboardKey.keyX,
                            control: !meta,
                            meta: meta,
                            shift: true,
                          ): () => _apply((v) => toggleInline(v, '~~')),
                          SingleActivator(
                            LogicalKeyboardKey.keyK,
                            control: !meta,
                            meta: meta,
                          ): () => unawaited(promptForLink(context, _body)),
                        },
                      },
                      child: TextField(
                        key: const Key('note-body'),
                        controller: _body,
                        focusNode: _bodyFocus,
                        undoController: _undo,
                        maxLines: null,
                        minLines: 6,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        inputFormatters: [ListContinuationFormatter()],
                        decoration: InputDecoration(
                          hintText: l.noteBodyHint,
                          filled: false,
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    PhotoStrip(
                      parentKind: PhotoParent.note,
                      parentId: note.id,
                    ),
                    NoteListPicker(note: note),
                    NoteDeleteAction(note: note),
                  ],
                ),
              ),
            ),
            ListenableBuilder(
              listenable: _bodyFocus,
              builder: (context, _) => _bodyFocus.hasFocus
                  ? NoteFormatToolbar(
                      controller: _body,
                      undoController: _undo,
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/notes/note_detail_screen_test.dart`
Expected: PASS, all tests (new and kept).

If `ctrl+B bolds the selection` fails because the key never reaches `CallbackShortcuts`, check whether `DefaultTextEditingShortcuts` binds Ctrl+B on the test platform; if so, move the bindings into a `Shortcuts` + `Actions` pair wrapping the `TextField` with the same activators and `CallbackAction`s -- a closer `Shortcuts` wins over the app-level one.

- [ ] **Step 5: Analyze and format**

Run: `dart format lib/features/notes test/features/notes && flutter analyze lib/features/notes test/features/notes`
Expected: "No issues found!" (the `note_body_view.dart` import is gone from the screen; `NoteBodyView` itself is removed in Task 6, it is only unused here, which the analyzer does not flag).

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/notes/ui/note_detail_screen.dart app/test/features/notes/note_detail_screen_test.dart
git commit -m "feat(app): edit a note's body in place with a markdown toolbar"
```

---

### Task 6: Remove the rendered view and its dependency

**Files:**
- Delete: `app/lib/features/notes/ui/note_body_view.dart`
- Delete: `app/test/features/notes/note_body_view_test.dart`
- Modify: `app/pubspec.yaml` (remove `flutter_markdown_plus: ^1.0.12`)
- Modify: `app/lib/l10n/app_en.arb`, `app_de.arb`, `app_it.arb` (remove `noteEditToggle`, `noteReadToggle`)
- Regenerate: `app/lib/l10n/app_localizations*.dart`, `pubspec.lock` at the workspace root

**Interfaces:**
- Consumes: nothing new.
- Produces: nothing; removal only.

- [ ] **Step 1: Confirm nothing else uses them**

Run (from repo root): `grep -rn "NoteBodyView\|note_body_view\|flutter_markdown_plus\|noteEditToggle\|noteReadToggle" app/lib app/test app/pubspec.yaml | grep -v "app_localizations"`
Expected: only the two files being deleted, the pubspec line and the six `.arb` lines.

- [ ] **Step 2: Delete and edit**

```bash
git rm app/lib/features/notes/ui/note_body_view.dart app/test/features/notes/note_body_view_test.dart
```

Remove the `flutter_markdown_plus: ^1.0.12` line from `app/pubspec.yaml`. Remove the `"noteEditToggle"` and `"noteReadToggle"` lines from each of the three `.arb` files. Then:

```bash
flutter pub get
flutter gen-l10n
```

Expected: `pub get` succeeds and `pubspec.lock` drops `flutter_markdown_plus` (and `markdown` if nothing else depends on it).

- [ ] **Step 3: Analyze**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 4: Run the notes tests**

Run: `flutter test --concurrency=2 test/features/notes`
Expected: PASS. Check the count covers the five new/updated test files (spans, commands, controller, toolbar, detail screen) plus the untouched `note_card`, `notes_repository`, `notes_screen` tests.

- [ ] **Step 5: Commit**

```bash
git add -A app/pubspec.yaml pubspec.lock app/lib/l10n/
git commit -m "chore(app): drop the rendered note view and flutter_markdown_plus"
```

(`git rm` already staged the deletions.)

---

### Task 7: Full verification and manual check

**Files:** none changed unless a problem is found.

- [ ] **Step 1: Full app test suite**

Run: `flutter test --concurrency=2 --exclude-tags design --coverage` (timeout 600 s; nothing else running `flutter test`).
Expected: all pass. Then `dart run ../tool/check_coverage.dart 80`. Expected: floor met.

- [ ] **Step 2: Manual check in the web build**

Follow the project's web browser-check routine (build with `--no-web-resources-cdn`, serve locally). Open a note and confirm:
- The body is editable immediately, no pencil.
- Typing `**milk**` paints "milk" bold with faint stars; `# Title` is large; `- [x] a` is struck.
- Clicking the body shows the toolbar at the bottom; clicking toolbar buttons with a mouse does not hide it.
- Bold/italic/strike/heading/list/checkbox/quote/code/code block/link each do what their tooltip says; undo reverts one step.
- Enter after `- a` gives `- `; Enter again ends the list.
- Leaving and reopening the note shows the saved text.

- [ ] **Step 3: Report**

Report test counts, coverage and anything the manual check found. Do not commit if nothing changed.
