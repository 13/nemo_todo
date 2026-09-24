# Note Read View and Todos Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a formatted read view the note screen can switch to, and let a selection, a line or a whole note become tasks through a confirm sheet, leaving task links in the note.

**Architecture:** Everything is UI in `app/lib/features/notes/ui/`. Pure functions (line model, markdown stripping, todo candidates, link insertion/removal) sit in small files with unit tests. Two widgets (`NoteReadView`, `MakeTodoSheet`) are testable on their own. `NoteDetailScreen` wires them together, using its existing save path for every body write. Spec: `docs/superpowers/specs/2026-09-23-note-read-view-and-todos-design.md`.

**Tech Stack:** Flutter 3.47 (via fvm), Riverpod, go_router, drift (through repositories), flutter_test with the `pumpApp` harness.

## Global Constraints

- UI only: no change to `Note`, `Task`, the database schema, sync, server or export.
- `Note.body` stays a plain markdown string; the only automatic writes are a checkbox tapped in the read view and the links make-todo inserts on confirm.
- Task link text is exactly `[→ task](nemo://task/<id>)`; on a line it is inserted with one leading space; for a whole note it goes on a new final line.
- Web links open only for http/https (`isWebLink`), via `openUrlProvider`.
- Read-view mode is stored in `KvStore` under key `notes.readView` as `'1'`/`'0'`; device-local, never synced.
- New l10n keys go in `app_en.arb`, `app_de.arb` and `app_it.arb`, then `flutter gen-l10n` regenerates `app_localizations*.dart` (committed).
- Toolchain: `export PATH=~/fvm/versions/3.47.2/bin:$PATH`, run from `app/`. Tests with `--concurrency=2`, one `flutter test` process at a time, 600 s timeout (shared machine runs out of memory otherwise). Pass test directories or a single file, not long lists of paths.
- Commit messages end with the attribution lines in the session's system reminder.
- Work on branch `feat/note-read-view-todos` (already checked out, spec committed).

## File Structure

| File | Responsibility |
|---|---|
| `lib/features/notes/ui/markdown/markdown_spans.dart` (modify) | add `stripMarkdown` (pure) |
| `lib/features/notes/ui/markdown/read_lines.dart` (create) | `ReadLine`, `readLines`, `toggleTaskAt` (pure) |
| `lib/features/notes/ui/markdown/markdown_preview.dart` (modify) | generalise into `markdownSpan` with link taps and task-chip hook; `markdownPreviewSpan` wraps it |
| `lib/features/notes/ui/markdown/note_to_task.dart` (create) | `TodoCandidate`, `plainLine`, `todoCandidates`, `lineCandidate`, `linkedTaskAt`, `taskIdFromLink`, `insertTaskLinks`, `appendTaskLink`, `removeTaskLinks`, `wholeNoteTodo` (pure) |
| `lib/features/notes/ui/note_read_view.dart` (create) | `NoteReadView` widget |
| `lib/features/notes/ui/task_link_chip.dart` (create) | `TaskLinkChip`, `openNoteLink` |
| `lib/features/notes/ui/make_todo_sheet.dart` (create) | `MakeTodoResult`, `showMakeTodoSheet` |
| `lib/features/notes/ui/notes_providers.dart` (modify) | `noteReadViewProvider` |
| `lib/features/notes/ui/markdown/note_format_toolbar.dart` (modify) | make-todo / open-task button |
| `lib/features/notes/ui/note_detail_screen.dart` (modify) | toggle, read view, entry points, create/undo |
| `lib/l10n/app_{en,de,it}.arb` (modify) | strings |
| `CHANGELOG.md` (modify) | `## Unreleased` entries |

---

### Task 1: Pure line model and markdown stripping

**Files:**
- Modify: `app/lib/features/notes/ui/markdown/markdown_spans.dart` (append at end)
- Create: `app/lib/features/notes/ui/markdown/read_lines.dart`
- Test: `app/test/features/notes/markdown/read_lines_test.dart`

**Interfaces:**
- Produces: `String stripMarkdown(String text)`; `enum ReadKind { blank, text, heading, quote, bullet, numbered, task, rule, codeBlock }`; `class ReadLine { int start; int end; ReadKind kind; int contentStart; int level; bool checked; String marker; }`; `List<ReadLine> readLines(String body)`; `String toggleTaskAt(String body, int lineStart)`.

- [ ] **Step 1: Write the failing tests**

```dart
// app/test/features/notes/markdown/read_lines_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/notes/ui/markdown/markdown_spans.dart';
import 'package:nemo/features/notes/ui/markdown/read_lines.dart';

void main() {
  group('stripMarkdown', () {
    test('drops inline markers and link targets', () {
      expect(
        stripMarkdown('**500 g** _flour_ ~~no~~ `x` [recipe](https://a.io/b_c)'),
        '500 g flour no x recipe',
      );
    });

    test('drops a heading marker', () {
      expect(stripMarkdown('## Dough'), 'Dough');
    });
  });

  group('readLines', () {
    test('classifies each line and keeps source offsets', () {
      const body = '# Title\ntext\n- [x] done\n- [ ] open\n- bullet\n'
          '2. second\n> quoted\n---\n\n```\ncode\n```';
      final lines = readLines(body);
      expect(lines.map((l) => l.kind), [
        ReadKind.heading,
        ReadKind.text,
        ReadKind.task,
        ReadKind.task,
        ReadKind.bullet,
        ReadKind.numbered,
        ReadKind.quote,
        ReadKind.rule,
        ReadKind.blank,
        ReadKind.codeBlock,
      ]);
      final heading = lines[0];
      expect(heading.level, 1);
      expect(body.substring(heading.contentStart, heading.end), 'Title');
      expect(lines[2].checked, isTrue);
      expect(lines[3].checked, isFalse);
      expect(body.substring(lines[3].contentStart, lines[3].end), 'open');
      expect(lines[5].marker, '2.');
      expect(body.substring(lines[6].contentStart, lines[6].end), 'quoted');
      final code = lines.last;
      expect(body.substring(code.contentStart, code.end), 'code');
      expect(code.end, body.length);
    });

    test('an unclosed fence runs to the end of the body', () {
      final lines = readLines('a\n```\nx\ny');
      expect(lines.last.kind, ReadKind.codeBlock);
      expect('a\n```\nx\ny'.substring(lines.last.contentStart), 'x\ny');
    });

    test('indent is kept as level on list lines', () {
      final lines = readLines('  - nested');
      expect(lines.single.kind, ReadKind.bullet);
      expect(lines.single.level, 2);
    });
  });

  group('toggleTaskAt', () {
    test('ticks an open box and unticks a ticked one', () {
      const body = 'a\n- [ ] milk\n- [X] eggs';
      final ticked = toggleTaskAt(body, 2);
      expect(ticked, 'a\n- [x] milk\n- [X] eggs');
      expect(toggleTaskAt(ticked, 12), 'a\n- [x] milk\n- [ ] eggs');
    });

    test('leaves a non-task line alone', () {
      expect(toggleTaskAt('plain', 0), 'plain');
    });
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/notes/markdown/read_lines_test.dart`
Expected: compile errors, `stripMarkdown`/`read_lines.dart` not found.

- [ ] **Step 3: Implement**

Append to `markdown_spans.dart`:

```dart
/// [text] as it reads with its markdown markers removed: emphasis
/// delimiters, heading hashes, link brackets and targets. List markers are
/// left alone -- they are `listMarker`, not `marker`, and callers that want
/// them gone strip them first.
String stripMarkdown(String text) {
  final hidden = List<bool>.filled(text.length, false);
  for (final r in parseMarkdownRanges(text)) {
    if (r.style != MdStyle.marker) continue;
    for (var i = r.start; i < r.end; i++) {
      hidden[i] = true;
    }
  }
  final out = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    if (!hidden[i]) out.write(text[i]);
  }
  return out.toString();
}
```

Create `read_lines.dart`:

```dart
/// A note body split into the lines the read view draws, each with its
/// place in the source so a tap can be mapped back to the text.
library;

import 'package:meta/meta.dart';

enum ReadKind { blank, text, heading, quote, bullet, numbered, task, rule, codeBlock }

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
        out.add(ReadLine(
          start: start,
          end: body.length,
          kind: ReadKind.codeBlock,
          contentStart: contentStart,
        ));
        break;
      }
      final closeEnd = close + lines[j].length;
      out.add(ReadLine(
        start: start,
        // The content's last line break is not part of the code.
        end: closeEnd,
        kind: ReadKind.codeBlock,
        contentStart: contentStart,
      ));
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
  ReadLine at(ReadKind kind, int content,
          {int level = 0, bool checked = false, String marker = ''}) =>
      ReadLine(
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
    return at(ReadKind.task, m.end,
        level: m[1]!.length, checked: m[2] != ' ');
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
  return body.replaceRange(
    lineStart + box.start,
    lineStart + box.end,
    flipped,
  );
}
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/notes/markdown/read_lines_test.dart`
Expected: all pass. Then `dart format lib test && flutter analyze` -- no issues.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/notes/ui/markdown/markdown_spans.dart app/lib/features/notes/ui/markdown/read_lines.dart app/test/features/notes/markdown/read_lines_test.dart
git commit -m "feat(app): split a note body into read-view lines and strip its markdown"
```

---

### Task 2: Note-to-task pure functions

**Files:**
- Create: `app/lib/features/notes/ui/markdown/note_to_task.dart`
- Test: `app/test/features/notes/markdown/note_to_task_test.dart`

**Interfaces:**
- Consumes: `stripMarkdown` (Task 1).
- Produces:
  - `class TodoCandidate { const TodoCandidate({required String title, required int anchor}); }`
  - `String plainLine(String line)`
  - `List<TodoCandidate> todoCandidates(TextEditingValue v)`
  - `TodoCandidate? lineCandidate(String body, int lineStart)`
  - `String? linkedTaskAt(String body, int offset)`
  - `String? taskIdFromLink(String url)`
  - `String taskLink(String id)` → `'[→ task](nemo://task/$id)'`
  - `String insertTaskLinks(String body, List<(int, String)> links)`
  - `String appendTaskLink(String body, String id)`
  - `String removeTaskLinks(String body, Set<String> ids)`
  - `({String title, String notes, String notesWithoutChecklist, List<String> checklist}) wholeNoteTodo(String title, String body)`

- [ ] **Step 1: Write the failing tests**

```dart
// app/test/features/notes/markdown/note_to_task_test.dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/notes/ui/markdown/note_to_task.dart';

TextEditingValue _sel(String text, int start, [int? end]) => TextEditingValue(
  text: text,
  selection: TextSelection(baseOffset: start, extentOffset: end ?? start),
);

void main() {
  test('plainLine strips list, task, heading and inline markdown', () {
    expect(plainLine('- [ ] buy **milk**'), 'buy milk');
    expect(plainLine('  * see [shop](https://a.io)'), 'see shop');
    expect(plainLine('3. call _Bob_'), 'call Bob');
    expect(plainLine('## Plan'), 'Plan');
    expect(plainLine('- x [→ task](nemo://task/t1)'), 'x');
  });

  group('todoCandidates', () {
    test('a selection within a line anchors at the selection end', () {
      const text = 'call Bob tomorrow';
      final c = todoCandidates(_sel(text, 0, 8)).single;
      expect(c.title, 'call Bob');
      expect(c.anchor, 8);
    });

    test('a multi-line selection gives one per line, skipping blank, '
        'ticked and linked lines', () {
      const text = '- [ ] milk\n\n- [x] eggs\n- bread\n'
          '- jam [→ task](nemo://task/t1)\nflour';
      final cs = todoCandidates(_sel(text, 2, text.length));
      expect(cs.map((c) => c.title), ['milk', 'bread', 'flour']);
      expect(cs.first.anchor, 10);
      expect(cs.last.anchor, text.length);
    });

    test('a cursor on a list line takes that line', () {
      const text = 'intro\n- [ ] milk';
      final c = todoCandidates(_sel(text, 9)).single;
      expect(c.title, 'milk');
      expect(c.anchor, text.length);
    });

    test('a cursor on plain text gives nothing', () {
      expect(todoCandidates(_sel('just words', 3)), isEmpty);
    });
  });

  test('lineCandidate takes any non-empty unlinked line', () {
    const body = 'first\n- [x] done';
    expect(lineCandidate(body, 6)!.title, 'done');
    expect(lineCandidate(body, 6)!.anchor, body.length);
    expect(lineCandidate('a [→ task](nemo://task/t1)', 0), isNull);
    expect(lineCandidate('\n', 0), isNull);
  });

  test('linkedTaskAt finds a task link on the offset\'s line', () {
    const body = 'a\n- milk [→ task](nemo://task/t-1)\nb';
    expect(linkedTaskAt(body, 4), 't-1');
    expect(linkedTaskAt(body, 0), isNull);
  });

  test('taskIdFromLink reads nemo task links only', () {
    expect(taskIdFromLink('nemo://task/abc-1'), 'abc-1');
    expect(taskIdFromLink('https://a.io'), isNull);
  });

  test('insertTaskLinks keeps earlier anchors valid', () {
    const body = 'milk\nbread';
    final out = insertTaskLinks(body, [(4, 'a'), (10, 'b')]);
    expect(
      out,
      'milk [→ task](nemo://task/a)\nbread [→ task](nemo://task/b)',
    );
    expect(removeTaskLinks(out, {'a', 'b'}), body);
  });

  test('appendTaskLink puts the link on a new last line, and undoes', () {
    expect(appendTaskLink('', 'a'), '[→ task](nemo://task/a)');
    final out = appendTaskLink('text\n', 'a');
    expect(out, 'text\n\n[→ task](nemo://task/a)');
    expect(removeTaskLinks(out, {'a'}), 'text\n');
    expect(removeTaskLinks(appendTaskLink('', 'a'), {'a'}), '');
  });

  test('removeTaskLinks leaves other tasks\' links alone', () {
    const body = 'a [→ task](nemo://task/x) b [→ task](nemo://task/y)';
    expect(removeTaskLinks(body, {'x'}), 'a b [→ task](nemo://task/y)');
  });

  test('wholeNoteTodo splits out the open checklist', () {
    final w = wholeNoteTodo('Shop', 'For Sunday\n- [ ] milk\n- [x] eggs\n'
        '- [ ] **jam**');
    expect(w.title, 'Shop');
    expect(w.checklist, ['milk', 'jam']);
    expect(w.notes, 'For Sunday\n- [ ] milk\n- [x] eggs\n- [ ] **jam**');
    expect(w.notesWithoutChecklist, 'For Sunday\n- [x] eggs');
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/notes/markdown/note_to_task_test.dart`
Expected: compile error, file not found.

- [ ] **Step 3: Implement**

```dart
// app/lib/features/notes/ui/markdown/note_to_task.dart

/// Turning parts of a note into tasks: what a selection or line becomes,
/// and the links left behind in the note.
library;

import 'package:flutter/services.dart';
import 'package:meta/meta.dart';
import 'package:nemo/features/notes/ui/markdown/markdown_spans.dart';

/// A stretch of a note to become one task, and where its link goes.
@immutable
class TodoCandidate {
  const TodoCandidate({required this.title, required this.anchor});

  final String title;

  /// Offset in the body the task link is inserted at.
  final int anchor;

  @override
  String toString() => 'TodoCandidate($title @ $anchor)';
}

final _blockPrefix = RegExp(
  r'^\s*(?:[-*+] \[[ xX]\](?: |$)|[-*+] |\d+[.)] |#{1,6} |> )',
);
final _listLine = RegExp(r'^\s*(?:[-*+] |\d+[.)] )');
final _tickedLine = RegExp(r'^\s*[-*+] \[[xX]\](?: |$)');
final _openBoxLine = RegExp(r'^\s*[-*+] \[ \](?: |$)');
final _taskLinkAny = RegExp(r' ?\[[^\]]*\]\(nemo://task/([A-Za-z0-9_-]+)\)');
final _whitespace = RegExp(r'\s+');

String taskLink(String id) => '[→ task](nemo://task/$id)';

/// A line's text as a task title: no list, task, heading or quote marker,
/// no task links, no inline markdown, whitespace collapsed.
String plainLine(String line) {
  final bare = line
      .replaceFirst(_blockPrefix, '')
      .replaceAll(_taskLinkAny, '');
  return stripMarkdown(bare).replaceAll(_whitespace, ' ').trim();
}

(int, int) _lineAt(String text, int offset) {
  final start = offset == 0 ? 0 : text.lastIndexOf('\n', offset - 1) + 1;
  final nl = text.indexOf('\n', offset);
  return (start, nl == -1 ? text.length : nl);
}

bool _linked(String line) => _taskLinkAny.hasMatch(line);

/// What "Make todo" acts on in the editor: a selection within one line
/// as one task anchored at its end; a selection over several lines as one
/// task per line, leaving out blank, ticked and already linked lines; with
/// no selection, the unticked, unlinked list line under the cursor.
List<TodoCandidate> todoCandidates(TextEditingValue v) {
  final sel = v.selection;
  if (!sel.isValid) return const [];
  final text = v.text;
  if (sel.isCollapsed) {
    final (ls, le) = _lineAt(text, sel.start);
    final line = text.substring(ls, le);
    if (!_listLine.hasMatch(line) || _tickedLine.hasMatch(line)) {
      return const [];
    }
    if (_linked(line)) return const [];
    final title = plainLine(line);
    return title.isEmpty ? const [] : [TodoCandidate(title: title, anchor: le)];
  }
  final selected = text.substring(sel.start, sel.end);
  if (!selected.contains('\n')) {
    final title = plainLine(selected);
    return title.isEmpty
        ? const []
        : [TodoCandidate(title: title, anchor: sel.end)];
  }
  final out = <TodoCandidate>[];
  var (ls, _) = _lineAt(text, sel.start);
  while (ls <= sel.end && ls <= text.length) {
    final (_, le) = _lineAt(text, ls);
    final line = text.substring(ls, le);
    final title = plainLine(line);
    if (title.isNotEmpty && !_tickedLine.hasMatch(line) && !_linked(line)) {
      out.add(TodoCandidate(title: title, anchor: le));
    }
    if (le >= text.length) break;
    ls = le + 1;
  }
  return out;
}

/// The line starting at [lineStart] as a task, for the read view's
/// long-press; null when it is empty or already linked.
TodoCandidate? lineCandidate(String body, int lineStart) {
  final (_, le) = _lineAt(body, lineStart);
  final line = body.substring(lineStart, le);
  if (_linked(line)) return null;
  final title = plainLine(line);
  return title.isEmpty ? null : TodoCandidate(title: title, anchor: le);
}

/// The id of the task linked on the line containing [offset], if any.
String? linkedTaskAt(String body, int offset) {
  if (offset < 0 || offset > body.length) return null;
  final (ls, le) = _lineAt(body, offset);
  return _taskLinkAny.firstMatch(body.substring(ls, le))?[1];
}

final _taskUrl = RegExp(r'^nemo://task/([A-Za-z0-9_-]+)$');

String? taskIdFromLink(String url) => _taskUrl.firstMatch(url)?[1];

/// [body] with ` [→ task](nemo://task/<id>)` inserted at each anchor.
/// Applied from the last anchor back, so earlier offsets stay valid.
String insertTaskLinks(String body, List<(int, String)> links) {
  final sorted = [...links]..sort((a, b) => b.$1.compareTo(a.$1));
  var out = body;
  for (final (anchor, id) in sorted) {
    out = out.replaceRange(anchor, anchor, ' ${taskLink(id)}');
  }
  return out;
}

/// [body] with a task link on a new last line.
String appendTaskLink(String body, String id) =>
    body.isEmpty ? taskLink(id) : '$body\n${taskLink(id)}';

/// [body] with the links to [ids] taken out again: a link on its own last
/// line goes with the line break before it, one inside a line with the
/// space before it.
String removeTaskLinks(String body, Set<String> ids) {
  var out = body;
  for (final id in ids) {
    final link = RegExp.escape(taskLink(id));
    out = out
        .replaceAll(RegExp('\\n$link\$'), '')
        .replaceAll(RegExp('^$link\$'), '')
        .replaceAll(RegExp(' $link'), '');
  }
  return out;
}

/// The whole note as a task: its title, its body as notes, and its open
/// checkboxes as possible subtasks -- with the body minus those lines for
/// when they become subtasks.
({
  String title,
  String notes,
  String notesWithoutChecklist,
  List<String> checklist,
})
wholeNoteTodo(String title, String body) {
  final lines = body.split('\n');
  final checklist = <String>[];
  final kept = <String>[];
  for (final line in lines) {
    if (_openBoxLine.hasMatch(line) && plainLine(line).isNotEmpty) {
      checklist.add(plainLine(line));
    } else {
      kept.add(line);
    }
  }
  return (
    title: title.trim(),
    notes: body,
    notesWithoutChecklist: kept.join('\n'),
    checklist: checklist,
  );
}
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/notes/markdown/note_to_task_test.dart`
Expected: all pass. `dart format lib test && flutter analyze` clean.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/notes/ui/markdown/note_to_task.dart app/test/features/notes/markdown/note_to_task_test.dart
git commit -m "feat(app): work out which note text becomes a task and link it back"
```

---

### Task 3: Generalise the span builder, add the task chip and link opener

**Files:**
- Modify: `app/lib/features/notes/ui/markdown/markdown_preview.dart`
- Create: `app/lib/features/notes/ui/task_link_chip.dart`
- Modify: `app/lib/l10n/app_en.arb`, `app_de.arb`, `app_it.arb` (+ regenerate)
- Test: `app/test/features/notes/markdown/markdown_preview_test.dart`, `app/test/features/notes/task_link_chip_test.dart`

**Interfaces:**
- Consumes: `taskIdFromLink` (Task 2); `isWebLink`, `openUrlProvider` (existing); `taskByIdProvider` (existing, `tasks_providers.dart`).
- Produces:
  - `TextSpan markdownSpan(String text, TextStyle base, ThemeData theme, {bool capHeadings = false, GestureRecognizer? Function(String url)? linkRecognizer, Widget Function(String taskId)? taskChip})`
  - `TextSpan markdownPreviewSpan(String text, TextStyle base, ThemeData theme)` (unchanged signature)
  - `class TaskLinkChip extends ConsumerWidget { const TaskLinkChip({required String taskId}); }` keyed `task-link-chip-<id>`
  - `void openNoteLink(BuildContext context, WidgetRef ref, String url)`
  - l10n `noteTaskDeleted`

- [ ] **Step 1: Add the l10n key**

In `app_en.arb`, before the closing `}` (after `"mdRedo": "Redo"`, adding a comma to it):

```json
  "noteTaskDeleted": "Task deleted",
  "@noteTaskDeleted": {
    "description": "Label of a task link chip in a note when the linked task no longer exists."
  }
```

`app_de.arb`: `"noteTaskDeleted": "Aufgabe gelöscht"`. `app_it.arb`: `"noteTaskDeleted": "Attività eliminata"`.

Run: `flutter gen-l10n`

- [ ] **Step 2: Write the failing tests**

```dart
// app/test/features/notes/markdown/markdown_preview_test.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/notes/ui/markdown/markdown_preview.dart';

void main() {
  final theme = ThemeData();
  const base = TextStyle(fontSize: 14);

  test('a web link gets the recogniser for its URL', () {
    final urls = <String>[];
    final span = markdownSpan(
      'see [shop](https://a.io/x_(y)) now',
      base,
      theme,
      linkRecognizer: (url) {
        urls.add(url);
        return TapGestureRecognizer();
      },
    );
    expect(span.toPlainText(), 'see shop now');
    expect(urls, ['https://a.io/x_(y)']);
    final link = span.children!.cast<TextSpan>().firstWhere(
      (s) => s.text == 'shop',
    );
    expect(link.recognizer, isA<TapGestureRecognizer>());
  });

  test('a task link becomes the chip in place of its text', () {
    final span = markdownSpan(
      'milk [→ task](nemo://task/t1)',
      base,
      theme,
      taskChip: (id) => Text('chip $id'),
    );
    final chip = span.children!.whereType<WidgetSpan>().single;
    expect((chip.child as Text).data, 'chip t1');
    expect(
      span.children!.whereType<TextSpan>().map((s) => s.text).join(),
      'milk ',
    );
  });

  test('headings are full size unless capped', () {
    TextStyle? size(bool cap) => markdownSpan(
      '# Big',
      base,
      theme,
      capHeadings: cap,
    ).children!.cast<TextSpan>().single.style;
    expect(size(false)!.fontSize, theme.textTheme.headlineSmall!.fontSize);
    expect(size(true)!.fontSize, closeTo(14 * 1.2, 0.01));
  });
}
```

```dart
// app/test/features/notes/task_link_chip_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/notes/ui/task_link_chip.dart';
import 'package:nemo/features/tasks/ui/tasks_providers.dart';

import '../../support/pump_app.dart';

void main() {
  appTest('the chip follows the task and opens it', (tester) async {
    final app = await pumpApp(tester, initialLocation: '/notes');
    await app.seedList('l1', 'Kitchen');
    await app.seedTask('t1', 'l1', title: 'Buy milk');
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      app.wrap(const Scaffold(body: TaskLinkChip(taskId: 't1'))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Buy milk'), findsOneWidget);
    expect(find.byIcon(Icons.task_alt), findsOneWidget);

    await app.container.read(tasksRepositoryProvider).setDone('t1', done: true);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    await app.container.read(tasksRepositoryProvider).delete('t1');
    await tester.pumpAndSettle();
    expect(find.text('Task deleted'), findsOneWidget);
  });
}
```

`pump_app.dart` has no helper that pumps a bare widget with the harness's providers; add one to the `SeedTestApp` extension (imports `flutter_riverpod`, `L` and `MaterialApp` are already there):

```dart
  /// [child] inside this harness's providers, theme and localisations, for
  /// a widget test that needs the database but not the whole router.
  Widget wrap(Widget child) => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      home: child,
    ),
  );
```

(The "opens it" half is covered in Task 7's screen test, where the router exists.)

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/features/notes/markdown/markdown_preview_test.dart` then `flutter test test/features/notes/task_link_chip_test.dart`
Expected: `markdownSpan` / `task_link_chip.dart` not found.

- [ ] **Step 4: Implement `markdownSpan`**

Replace the body of `markdown_preview.dart` with:

```dart
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
```

Note `markdownSpan` returns children typed `InlineSpan`; the card test from 0.11.1 casts children to `TextSpan` -- a preview never has a `taskChip`, so its children are all `TextSpan` and that test still passes.

- [ ] **Step 5: Implement the chip and the opener**

```dart
// app/lib/features/notes/ui/task_link_chip.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/features/notes/ui/markdown/note_format_toolbar.dart'
    show isWebLink;
import 'package:nemo/features/notes/ui/markdown/note_to_task.dart';
import 'package:nemo/features/settings/ui/about_tile.dart' show openUrlProvider;
import 'package:nemo/features/tasks/ui/tasks_providers.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/router.dart';

/// Opens a link tapped in a note: a task link in the app, a web link in
/// the browser, anything else not at all.
void openNoteLink(BuildContext context, WidgetRef ref, String url) {
  final taskId = taskIdFromLink(url);
  if (taskId != null) {
    unawaited(context.push(Routes.task(taskId)));
  } else if (isWebLink(url)) {
    unawaited(ref.read(openUrlProvider)(Uri.parse(url)));
  }
}

/// A task a note links to, drawn live in the read view: its title, and
/// whether it is open, done or gone. Tapping opens it.
class TaskLinkChip extends ConsumerWidget {
  const TaskLinkChip({required this.taskId, super.key});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final colors = Theme.of(context).colorScheme;
    final task = ref.watch(taskByIdProvider(taskId)).value;
    final gone = task == null || task.isDeleted;
    final (IconData icon, Color color, String label) = gone
        ? (Icons.remove_circle_outline, colors.outline, l.noteTaskDeleted)
        : task.done
        ? (Icons.check_circle, colors.primary, task.title)
        : (Icons.task_alt, colors.primary, task.title);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: ActionChip(
        key: Key('task-link-chip-$taskId'),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        avatar: Icon(icon, size: 16, color: color),
        label: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        onPressed: () => unawaited(context.push(Routes.task(taskId))),
      ),
    );
  }
}
```

- [ ] **Step 6: Run to verify pass**

Run: `flutter test test/features/notes` (directory; expect the existing notes tests plus the new ones all passing).
Then `dart format lib test && flutter analyze` clean.

- [ ] **Step 7: Commit**

```bash
git add app/lib/features/notes/ui/markdown/markdown_preview.dart app/lib/features/notes/ui/task_link_chip.dart app/lib/l10n app/test/features/notes app/test/support/pump_app.dart
git commit -m "feat(app): render note links as tappable text and task links as live chips"
```

---

### Task 4: `NoteReadView` widget

**Files:**
- Create: `app/lib/features/notes/ui/note_read_view.dart`
- Test: `app/test/features/notes/note_read_view_test.dart`

**Interfaces:**
- Consumes: `readLines`, `ReadLine`, `ReadKind`, `toggleTaskAt` (Task 1); `markdownSpan` (Task 3).
- Produces: `NoteReadView({required String body, required ValueChanged<String> onChanged, required ValueChanged<int> onEditAt, required void Function(int lineStart, Offset globalPosition) onLongPressLine, required ValueChanged<String> onOpenLink, Widget Function(String taskId)? taskChip})`, keyed by the caller. Each line widget is keyed `read-line-<index>`; a task checkbox `read-check-<index>`.

- [ ] **Step 1: Write the failing tests**

```dart
// app/test/features/notes/note_read_view_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/notes/ui/note_read_view.dart';

Future<void> _pump(
  WidgetTester tester, {
  required String body,
  ValueChanged<String>? onChanged,
  ValueChanged<int>? onEditAt,
  void Function(int, Offset)? onLongPress,
  ValueChanged<String>? onOpenLink,
}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: NoteReadView(
        body: body,
        onChanged: onChanged ?? (_) {},
        onEditAt: onEditAt ?? (_) {},
        onLongPressLine: onLongPress ?? (_, _) {},
        onOpenLink: onOpenLink ?? (_) {},
      ),
    ),
  ),
);

void main() {
  testWidgets('shows markdown with its markers hidden', (tester) async {
    await _pump(tester, body: '# Dough\n**500 g** flour\n- salt\n```\nknead\n```');
    expect(find.text('Dough'), findsOneWidget);
    expect(find.textContaining('**'), findsNothing);
    expect(find.textContaining('500 g flour', findRichText: true), findsOneWidget);
    expect(find.textContaining('•', findRichText: true), findsOneWidget);
    expect(find.textContaining('knead', findRichText: true), findsOneWidget);
    expect(find.textContaining('```', findRichText: true), findsNothing);
  });

  testWidgets('tapping a checkbox writes the flipped body', (tester) async {
    String? written;
    await _pump(
      tester,
      body: 'list\n- [ ] milk',
      onChanged: (b) => written = b,
    );
    await tester.tap(find.byKey(const Key('read-check-1')));
    expect(written, 'list\n- [x] milk');
  });

  testWidgets('tapping text asks to edit at that line', (tester) async {
    int? at;
    await _pump(tester, body: 'one\ntwo', onEditAt: (o) => at = o);
    await tester.tap(find.byKey(const Key('read-line-1')));
    expect(at, 4);
  });

  testWidgets('long-press reports the line', (tester) async {
    int? at;
    await _pump(
      tester,
      body: 'one\n- [ ] two',
      onLongPress: (o, _) => at = o,
    );
    await tester.longPress(find.byKey(const Key('read-line-1')));
    expect(at, 4);
  });

  testWidgets('tapping a web link opens it instead of editing', (tester) async {
    String? opened;
    int? at;
    await _pump(
      tester,
      body: '[shop](https://a.io)',
      onOpenLink: (u) => opened = u,
      onEditAt: (o) => at = o,
    );
    await tester.tapOnText(find.textRange.ofSubstring('shop'));
    expect(opened, 'https://a.io');
    expect(at, isNull);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/notes/note_read_view_test.dart`
Expected: `note_read_view.dart` not found.

- [ ] **Step 3: Implement**

```dart
// app/lib/features/notes/ui/note_read_view.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:nemo/features/notes/ui/markdown/markdown_preview.dart';
import 'package:nemo/features/notes/ui/markdown/read_lines.dart';

/// A note body as formatted text, markers hidden: the read half of the
/// note screen's toggle.
///
/// Writes nothing itself. A tapped checkbox hands the flipped body to
/// [onChanged]; a tap anywhere else on a line asks to edit there through
/// [onEditAt]; a long-press hands the line to [onLongPressLine].
class NoteReadView extends StatefulWidget {
  const NoteReadView({
    required this.body,
    required this.onChanged,
    required this.onEditAt,
    required this.onLongPressLine,
    required this.onOpenLink,
    this.taskChip,
    super.key,
  });

  final String body;
  final ValueChanged<String> onChanged;
  final ValueChanged<int> onEditAt;
  final void Function(int lineStart, Offset globalPosition) onLongPressLine;
  final ValueChanged<String> onOpenLink;
  final Widget Function(String taskId)? taskChip;

  @override
  State<NoteReadView> createState() => _NoteReadViewState();
}

class _NoteReadViewState extends State<NoteReadView> {
  // Recognisers made for the last build's links; disposed on the next
  // build and on dispose, as a TextSpan does not own them.
  final _recognizers = <GestureRecognizer>[];

  void _clearRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _clearRecognizers();
    super.dispose();
  }

  GestureRecognizer _recognizer(String url) {
    final r = TapGestureRecognizer()..onTap = () => widget.onOpenLink(url);
    _recognizers.add(r);
    return r;
  }

  @override
  Widget build(BuildContext context) {
    _clearRecognizers();
    final theme = Theme.of(context);
    final t = theme.textTheme;
    final c = theme.colorScheme;
    final body = widget.body;
    final lines = readLines(body);

    InlineSpan inline(ReadLine line, TextStyle style) => markdownSpan(
      body.substring(line.contentStart, line.end),
      style,
      theme,
      linkRecognizer: _recognizer,
      taskChip: widget.taskChip,
    );

    Widget rich(ReadLine line, TextStyle style) =>
        Text.rich(inline(line, style), style: style);

    final base = t.bodyLarge ?? const TextStyle();
    final children = <Widget>[];
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final indent = line.level * 8.0;
      final Widget content = switch (line.kind) {
        ReadKind.blank => const SizedBox(height: 8),
        ReadKind.rule => const Divider(),
        ReadKind.text => rich(line, base),
        ReadKind.heading => rich(
          line,
          (switch (line.level) {
                    1 => t.headlineSmall,
                    2 => t.titleLarge,
                    3 => t.titleMedium,
                    _ => t.titleSmall,
                  } ??
                  base)
              .copyWith(fontWeight: FontWeight.w700),
        ),
        ReadKind.quote => Container(
          padding: const EdgeInsets.only(left: 12),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: c.outlineVariant, width: 3)),
          ),
          child: rich(
            line,
            base.copyWith(fontStyle: FontStyle.italic, color: c.onSurfaceVariant),
          ),
        ),
        ReadKind.bullet || ReadKind.numbered => Padding(
          padding: EdgeInsets.only(left: indent),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                child: Text(
                  line.kind == ReadKind.bullet ? '•' : line.marker,
                  style: base.copyWith(color: c.onSurfaceVariant),
                ),
              ),
              Expanded(child: rich(line, base)),
            ],
          ),
        ),
        ReadKind.task => Padding(
          padding: EdgeInsets.only(left: indent),
          child: Row(
            children: [
              Checkbox(
                key: Key('read-check-$i'),
                value: line.checked,
                visualDensity: VisualDensity.compact,
                onChanged: (_) =>
                    widget.onChanged(toggleTaskAt(body, line.start)),
              ),
              Expanded(
                child: rich(
                  line,
                  line.checked
                      ? base.copyWith(
                          decoration: TextDecoration.lineThrough,
                          color: c.onSurfaceVariant,
                        )
                      : base,
                ),
              ),
            ],
          ),
        ),
        ReadKind.codeBlock => Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              body.substring(line.contentStart, line.end).replaceFirst(
                RegExp(r'\n\s*```.*$'),
                '',
              ),
              style: base.copyWith(
                fontFamily: 'monospace',
                fontFamilyFallback: const ['Courier New', 'Courier'],
              ),
            ),
          ),
        ),
      };
      children.add(
        GestureDetector(
          key: Key('read-line-$i'),
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onEditAt(line.start),
          onLongPressStart: (d) =>
              widget.onLongPressLine(line.start, d.globalPosition),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: content,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }
}
```

Code block content: `readLines` ends a closed block at the end of the closing fence, so the text from `contentStart` includes `\n```` at the end; the `replaceFirst` drops it. For an unclosed block there is no closing fence and nothing is removed.

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/notes/note_read_view_test.dart`
Expected: all pass. `dart format lib test && flutter analyze` clean.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/notes/ui/note_read_view.dart app/test/features/notes/note_read_view_test.dart
git commit -m "feat(app): add a formatted read view for a note body"
```

---

### Task 5: Read-view toggle on the note screen

**Files:**
- Modify: `app/lib/features/notes/ui/notes_providers.dart`
- Modify: `app/lib/features/notes/ui/note_detail_screen.dart`
- Modify: `app/lib/l10n/app_{en,de,it}.arb` (+ regenerate)
- Test: `app/test/features/notes/note_detail_screen_test.dart`

**Interfaces:**
- Consumes: `NoteReadView` (Task 4), `TaskLinkChip`, `openNoteLink` (Task 3), `kvStoreProvider` (existing).
- Produces: `noteReadViewProvider` (`StreamProvider<bool>`), `const noteReadViewKey = 'notes.readView'`; in the screen: `_readView` state, `Future<bool> _writeBody(String body)`, `void _editAt(int offset)`; toggle keyed `note-view-toggle`; read view keyed `note-read-view`. l10n `noteReadToggle`, `noteEditToggle`.

- [ ] **Step 1: l10n**

`app_en.arb` (append):

```json
  "noteReadToggle": "Formatted",
  "@noteReadToggle": {
    "description": "Tooltip of the note app bar button that switches the body to the formatted read view."
  },
  "noteEditToggle": "Markdown",
  "@noteEditToggle": {
    "description": "Tooltip of the note app bar button that switches the body back to editing its markdown."
  }
```

de: `"noteReadToggle": "Formatiert"`, `"noteEditToggle": "Markdown"`. it: `"noteReadToggle": "Formattato"`, `"noteEditToggle": "Markdown"`. Run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing tests**

Add to `note_detail_screen_test.dart` inside `main()`. Also rename the existing test `'the body is editable markdown source with no toggle'` to `'the body opens as editable markdown source'` and change its `note-edit-toggle` expectation to:

```dart
    expect(find.byKey(const Key('note-read-view')), findsNothing);
```

New tests:

```dart
  appTest('the toggle switches to the read view and back, and is '
      'remembered', (tester) async {
    final harness = await pumpApp(tester, initialLocation: '/notes/n1');
    await harness.seedList('l1', 'Kitchen');
    await harness.seedNote('n1', 'l1', title: 'Bread', body: '**milk**');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('note-view-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('note-read-view')), findsOneWidget);
    expect(find.byKey(const Key('note-body')), findsNothing);
    expect(
      await harness.container.read(kvStoreProvider).get('notes.readView'),
      '1',
    );

    // Reopened, it comes back in the read view.
    harness.router.go('/notes');
    await tester.pumpAndSettle();
    harness.router.go('/notes/n1');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('note-read-view')), findsOneWidget);

    await tester.tap(find.byKey(const Key('note-view-toggle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('note-body')), findsOneWidget);
  });

  appTest('an empty note opens in the editor even after the read view', (
    tester,
  ) async {
    final harness = await pumpApp(tester, initialLocation: '/notes/n1');
    await harness.container.read(kvStoreProvider).set('notes.readView', '1');
    await harness.seedList('l1', 'Kitchen');
    await harness.seedNote('n1', 'l1', title: 'Bread', body: '');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('note-body')), findsOneWidget);
  });

  appTest('a checkbox tapped in the read view saves the note', (tester) async {
    final harness = await pumpApp(tester, initialLocation: '/notes/n1');
    await harness.container.read(kvStoreProvider).set('notes.readView', '1');
    await harness.seedList('l1', 'Kitchen');
    await harness.seedNote('n1', 'l1', title: 'Bread', body: '- [ ] milk');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('read-check-0')));
    await tester.pumpAndSettle();
    final note = await harness.container
        .read(notesRepositoryProvider)
        .watch('n1')
        .first;
    expect(note!.body, '- [x] milk');
  });

  appTest('tapping read-view text edits with the cursor on that line', (
    tester,
  ) async {
    final harness = await pumpApp(tester, initialLocation: '/notes/n1');
    await harness.container.read(kvStoreProvider).set('notes.readView', '1');
    await harness.seedList('l1', 'Kitchen');
    await harness.seedNote('n1', 'l1', title: 'Bread', body: 'one\ntwo');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('read-line-1')));
    await tester.pumpAndSettle();
    final field = bodyField(tester);
    expect(field.focusNode!.hasFocus, isTrue);
    expect(field.controller!.selection, const TextSelection.collapsed(offset: 4));
  });
```

Add imports if missing: `package:nemo/core/providers.dart` (already), `package:nemo/features/notes/ui/notes_providers.dart` (already).

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/features/notes/note_detail_screen_test.dart`
Expected: the four new tests fail (`note-view-toggle` not found).

- [ ] **Step 4: Provider**

Append to `notes_providers.dart` (outside any generated part; it is a plain provider like `tasksRepositoryProvider`):

```dart
/// KvStore key for whether notes open in the read view: `'1'` or `'0'`.
/// Device-local, like every KvStore entry -- it is how this person likes
/// to read here, not a property of any note.
const noteReadViewKey = 'notes.readView';

/// Whether notes open in the formatted read view rather than the editor.
final noteReadViewProvider = StreamProvider<bool>(
  (ref) => ref
      .watch(kvStoreProvider)
      .watch(noteReadViewKey)
      .map((value) => value == '1'),
);
```

- [ ] **Step 5: Screen**

In `note_detail_screen.dart`:

Imports: add

```dart
import 'package:nemo/core/providers.dart';
import 'package:nemo/features/notes/ui/note_read_view.dart';
import 'package:nemo/features/notes/ui/task_link_chip.dart';
```

State fields, after `_lastBody`:

```dart
  // The mode chosen on this page, which wins over the stored preference
  // from the first toggle on: the preference's stream answers a frame or
  // more after the write, and the page must switch at once. Null until
  // then, when the preference decides -- except for an empty note, which
  // opens in the editor since there is nothing to read.
  bool? _readView;
  bool? _openedEmpty;
```

Methods, after `_insertLink`:

```dart
  bool _showReadView(Note note) {
    _openedEmpty ??= note.body.trim().isEmpty;
    if (_readView case final chosen?) return chosen;
    if (_openedEmpty!) return false;
    return ref.watch(noteReadViewProvider).value ?? false;
  }

  Future<void> _setReadView(bool read) async {
    if (read) {
      _bodyFocus.unfocus();
      await _save();
    }
    if (!mounted) return;
    setState(() => _readView = read);
    await ref.read(kvStoreProvider).set(noteReadViewKey, read ? '1' : '0');
  }

  /// Leaves the read view for the editor, the cursor at [offset].
  void _editAt(int offset) {
    unawaited(_setReadView(false));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _body.selection = TextSelection.collapsed(offset: offset);
      _bodyFocus.requestFocus();
    });
  }

  /// Writes [body] as an edit of the body, through the same save path as
  /// typing: for writes that come from outside the field -- a checkbox in
  /// the read view, task links from make-todo.
  Future<bool> _writeBody(String body) {
    final sel = _body.selection;
    _body.value = TextEditingValue(
      text: body,
      selection: sel.isValid && sel.end <= body.length
          ? sel
          : TextSelection.collapsed(offset: body.length),
    );
    _bodyDirty = true;
    // The read view draws from `_body.text`; nothing else rebuilds it.
    setState(() {});
    return _save();
  }
```

In `build`, after `_fill(note);`:

```dart
    final readView = _showReadView(note);
```

App bar:

```dart
        appBar: AppBar(
          actions: [
            IconButton(
              key: const Key('note-view-toggle'),
              tooltip: readView ? l.noteEditToggle : l.noteReadToggle,
              icon: Icon(
                readView ? Icons.edit_outlined : Icons.visibility_outlined,
              ),
              onPressed: () => unawaited(_setReadView(!readView)),
            ),
            NotePinAction(note: note),
          ],
        ),
```

Replace the `CallbackShortcuts(...)` child in the `ListView` with:

```dart
                    if (readView)
                      NoteReadView(
                        key: const Key('note-read-view'),
                        body: _body.text,
                        onChanged: (body) => unawaited(_writeBody(body)),
                        onEditAt: _editAt,
                        onLongPressLine: (_, _) {},
                        onOpenLink: (url) => openNoteLink(context, ref, url),
                        taskChip: (id) => TaskLinkChip(taskId: id),
                      )
                    else
                      CallbackShortcuts(
                        // ... unchanged ...
                      ),
```

(`onLongPressLine` is wired in Task 7.)

`_body.text` is the source of truth in both modes: `_fill` keeps it in step with the store while the body is unfocused, which it always is in the read view.

- [ ] **Step 6: Run to verify pass**

Run: `flutter test test/features/notes`
Expected: all pass, including the renamed test. `dart format lib test && flutter analyze` clean.

- [ ] **Step 7: Commit**

```bash
git add app/lib/features/notes/ui app/lib/l10n app/test/features/notes/note_detail_screen_test.dart
git commit -m "feat(app): switch a note between its markdown and a formatted read view"
```

---

### Task 6: `MakeTodoSheet`

**Files:**
- Create: `app/lib/features/notes/ui/make_todo_sheet.dart`
- Modify: `app/lib/l10n/app_{en,de,it}.arb` (+ regenerate)
- Test: `app/test/features/notes/make_todo_sheet_test.dart`

**Interfaces:**
- Consumes: `TodoCandidate`, `wholeNoteTodo` record (Task 2); `allListsProvider` (existing, `lists_providers.dart`); `dateLabel` (`utils/format.dart`), `dayStartMs` (`utils/dates.dart`); `nowProvider`.
- Produces:

```dart
class TodoDraft { const TodoDraft({required String title, List<String> subtasks = const [], String notes = ''}); }
class MakeTodoResult {
  const MakeTodoResult({required List<TodoDraft> tasks, required String listId, int? dueAt, int priority = 0});
}
typedef WholeNoteTodo = ({String title, String notes, String notesWithoutChecklist, List<String> checklist});
Future<MakeTodoResult?> showMakeTodoSheet(BuildContext context, {List<TodoCandidate> candidates = const [], WholeNoteTodo? wholeNote, required String listId});
```

Result shape contract (Task 7 relies on it): per-line mode returns one `TodoDraft` per candidate, in candidate order; subtasks mode and single-candidate mode return one draft; whole-note mode returns one draft whose `notes` is the note body (or `notesWithoutChecklist` when the checklist became subtasks).

Keys: `todo-title`, `todo-shape-lines`, `todo-shape-subtasks`, `todo-line-<i>`, `todo-checklist-subtasks`, `todo-list`, `todo-due`, `todo-priority-<0..3>`, `todo-create`.

- [ ] **Step 1: l10n**

en (append):

```json
  "noteMakeTodo": "Make todo",
  "@noteMakeTodo": {
    "description": "Action that turns the selected note text or line into a task."
  },
  "noteMakeTodoFromNote": "Make todo from note",
  "@noteMakeTodoFromNote": {
    "description": "Row on the note page that turns the whole note into a task."
  },
  "noteOpenTask": "Open task",
  "@noteOpenTask": {
    "description": "Action on a note line that already links to a task; opens that task."
  },
  "noteTodoPerLine": "One task per line",
  "@noteTodoPerLine": {
    "description": "Make-todo sheet choice: each selected line becomes its own task."
  },
  "noteTodoWithSubtasks": "One task with subtasks",
  "@noteTodoWithSubtasks": {
    "description": "Make-todo sheet choice: the first selected line is the task, the rest its subtasks."
  },
  "noteTodoChecklistSubtasks": "Checklist becomes subtasks",
  "@noteTodoChecklistSubtasks": {
    "description": "Make-todo sheet switch for a whole note: its open checkboxes become subtasks of the new task."
  },
  "noteTodoCreate": "Create",
  "@noteTodoCreate": {
    "description": "Make-todo sheet button that creates the task(s)."
  },
  "noteTodoCreated": "{count, plural, =1{Task created} other{{count} tasks created}}",
  "@noteTodoCreated": {
    "description": "Snackbar after make-todo created tasks.",
    "placeholders": {"count": {"type": "int"}}
  },
  "noteTodoFailed": "Couldn't create the task",
  "@noteTodoFailed": {
    "description": "Snackbar when creating tasks from a note fails; nothing was changed."
  },
  "commonOpen": "Open",
  "@commonOpen": {
    "description": "Generic action that opens the thing a message is about."
  }
```

(Check first that `commonOpen` does not exist yet: `grep -n '"commonOpen"' lib/l10n/app_en.arb`; skip it if it does.)

de: `"noteMakeTodo": "Als Aufgabe"`, `"noteMakeTodoFromNote": "Aufgabe aus Notiz"`, `"noteOpenTask": "Aufgabe öffnen"`, `"noteTodoPerLine": "Eine Aufgabe pro Zeile"`, `"noteTodoWithSubtasks": "Eine Aufgabe mit Unteraufgaben"`, `"noteTodoChecklistSubtasks": "Checkliste wird zu Unteraufgaben"`, `"noteTodoCreate": "Erstellen"`, `"noteTodoCreated": "{count, plural, =1{Aufgabe erstellt} other{{count} Aufgaben erstellt}}"`, `"noteTodoFailed": "Aufgabe konnte nicht erstellt werden"`, `"commonOpen": "Öffnen"`.

it: `"noteMakeTodo": "Crea attività"`, `"noteMakeTodoFromNote": "Attività dalla nota"`, `"noteOpenTask": "Apri attività"`, `"noteTodoPerLine": "Un'attività per riga"`, `"noteTodoWithSubtasks": "Un'attività con sottoattività"`, `"noteTodoChecklistSubtasks": "La checklist diventa sottoattività"`, `"noteTodoCreate": "Crea"`, `"noteTodoCreated": "{count, plural, =1{Attività creata} other{{count} attività create}}"`, `"noteTodoFailed": "Impossibile creare l'attività"`, `"commonOpen": "Apri"`.

Run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing tests**

```dart
// app/test/features/notes/make_todo_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/notes/ui/make_todo_sheet.dart';
import 'package:nemo/features/notes/ui/markdown/note_to_task.dart';

import '../../support/pump_app.dart';

void main() {
  Future<MakeTodoResult?> open(
    WidgetTester tester,
    TestApp app, {
    List<TodoCandidate> candidates = const [],
    WholeNoteTodo? wholeNote,
    Future<void> Function()? interact,
  }) async {
    MakeTodoResult? result;
    await tester.pumpWidget(
      app.wrap(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await showMakeTodoSheet(
                context,
                candidates: candidates,
                wholeNote: wholeNote,
                listId: 'l1',
              ),
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await interact?.call();
    await tester.tap(find.byKey(const Key('todo-create')));
    await tester.pumpAndSettle();
    return result;
  }

  appTest('one candidate: editable title, list and priority', (tester) async {
    final app = await pumpApp(tester, initialLocation: '/notes');
    await app.seedList('l1', 'Kitchen');
    await tester.pumpAndSettle();

    final r = await open(
      tester,
      app,
      candidates: const [TodoCandidate(title: 'milk', anchor: 4)],
      interact: () async {
        await tester.enterText(find.byKey(const Key('todo-title')), 'oat milk');
        await tester.tap(find.byKey(const Key('todo-priority-3')));
        await tester.pump();
      },
    );
    expect(r!.tasks.single.title, 'oat milk');
    expect(r.listId, 'l1');
    expect(r.priority, 3);
    expect(r.dueAt, isNull);
  });

  appTest('several lines: one task per line by default', (tester) async {
    final app = await pumpApp(tester, initialLocation: '/notes');
    await app.seedList('l1', 'Kitchen');
    await tester.pumpAndSettle();

    final r = await open(
      tester,
      app,
      candidates: const [
        TodoCandidate(title: 'milk', anchor: 4),
        TodoCandidate(title: 'bread', anchor: 10),
      ],
    );
    expect(r!.tasks.map((t) => t.title), ['milk', 'bread']);
    expect(r.tasks.every((t) => t.subtasks.isEmpty), isTrue);
  });

  appTest('several lines as one task with subtasks', (tester) async {
    final app = await pumpApp(tester, initialLocation: '/notes');
    await app.seedList('l1', 'Kitchen');
    await tester.pumpAndSettle();

    final r = await open(
      tester,
      app,
      candidates: const [
        TodoCandidate(title: 'shop', anchor: 4),
        TodoCandidate(title: 'milk', anchor: 10),
        TodoCandidate(title: 'bread', anchor: 16),
      ],
      interact: () async {
        await tester.tap(find.byKey(const Key('todo-shape-subtasks')));
        await tester.pump();
      },
    );
    expect(r!.tasks.single.title, 'shop');
    expect(r.tasks.single.subtasks, ['milk', 'bread']);
  });

  appTest('whole note: checklist becomes subtasks unless switched off', (
    tester,
  ) async {
    final app = await pumpApp(tester, initialLocation: '/notes');
    await app.seedList('l1', 'Kitchen');
    await tester.pumpAndSettle();
    final whole = wholeNoteTodo('Shop', 'Sunday\n- [ ] milk');

    final on = await open(tester, app, wholeNote: whole);
    expect(on!.tasks.single.title, 'Shop');
    expect(on.tasks.single.subtasks, ['milk']);
    expect(on.tasks.single.notes, 'Sunday');

    final off = await open(
      tester,
      app,
      wholeNote: whole,
      interact: () async {
        await tester.tap(find.byKey(const Key('todo-checklist-subtasks')));
        await tester.pump();
      },
    );
    expect(off!.tasks.single.subtasks, isEmpty);
    expect(off.tasks.single.notes, 'Sunday\n- [ ] milk');
  });
}
```

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/features/notes/make_todo_sheet_test.dart`
Expected: `make_todo_sheet.dart` not found.

- [ ] **Step 4: Implement**

```dart
// app/lib/features/notes/ui/make_todo_sheet.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/core/widgets/max_width.dart';
import 'package:nemo/features/lists/ui/lists_providers.dart';
import 'package:nemo/features/notes/ui/markdown/note_to_task.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/utils/dates.dart';
import 'package:nemo/utils/format.dart';
import 'package:nemo_core/nemo_core.dart';

typedef WholeNoteTodo = ({
  String title,
  String notes,
  String notesWithoutChecklist,
  List<String> checklist,
});

/// One task the sheet asks for.
class TodoDraft {
  const TodoDraft({
    required this.title,
    this.subtasks = const [],
    this.notes = '',
  });

  final String title;
  final List<String> subtasks;
  final String notes;
}

/// What the person confirmed. Per-line mode has one draft per candidate,
/// in candidate order; every other mode has exactly one.
class MakeTodoResult {
  const MakeTodoResult({
    required this.tasks,
    required this.listId,
    this.dueAt,
    this.priority = 0,
  });

  final List<TodoDraft> tasks;
  final String listId;
  final int? dueAt;
  final int priority;
}

/// Asks how [candidates], or the [wholeNote], should become tasks. Null
/// when dismissed. Writes nothing: the caller creates the tasks.
Future<MakeTodoResult?> showMakeTodoSheet(
  BuildContext context, {
  required String listId,
  List<TodoCandidate> candidates = const [],
  WholeNoteTodo? wholeNote,
}) => showModalBottomSheet<MakeTodoResult>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _MakeTodoSheet(
    candidates: candidates,
    wholeNote: wholeNote,
    listId: listId,
  ),
);

enum _Shape { perLine, withSubtasks }

class _MakeTodoSheet extends ConsumerStatefulWidget {
  const _MakeTodoSheet({
    required this.candidates,
    required this.wholeNote,
    required this.listId,
  });

  final List<TodoCandidate> candidates;
  final WholeNoteTodo? wholeNote;
  final String listId;

  @override
  ConsumerState<_MakeTodoSheet> createState() => _MakeTodoSheetState();
}

class _MakeTodoSheetState extends ConsumerState<_MakeTodoSheet> {
  late final _title = TextEditingController(
    text: widget.wholeNote?.title ?? widget.candidates.firstOrNull?.title ?? '',
  );
  var _shape = _Shape.perLine;
  var _checklistAsSubtasks = true;
  String? _listId;
  int? _dueAt;
  var _priority = 0;

  bool get _several => widget.wholeNote == null && widget.candidates.length > 1;
  bool get _titled => !_several || _shape == _Shape.withSubtasks;

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final now = ref.read(nowProvider)();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueAt == null
          ? now
          : DateTime.fromMillisecondsSinceEpoch(_dueAt!),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _dueAt = dayStartMs(picked));
  }

  List<TodoDraft> _drafts() {
    final whole = widget.wholeNote;
    if (whole != null) {
      final sub = _checklistAsSubtasks && whole.checklist.isNotEmpty;
      return [
        TodoDraft(
          title: _title.text.trim(),
          subtasks: sub ? whole.checklist : const [],
          notes: sub ? whole.notesWithoutChecklist : whole.notes,
        ),
      ];
    }
    if (!_several) return [TodoDraft(title: _title.text.trim())];
    if (_shape == _Shape.withSubtasks) {
      return [
        TodoDraft(
          title: _title.text.trim(),
          subtasks: [for (final c in widget.candidates.skip(1)) c.title],
        ),
      ];
    }
    return [for (final c in widget.candidates) TodoDraft(title: c.title)];
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).toString();
    final lists = ref.watch(allListsProvider).value ?? const <TaskList>[];
    // The note's list, or Inbox when that list is gone.
    final listId =
        _listId ??
        (lists.any((x) => x.id == widget.listId)
            ? widget.listId
            : lists.where((x) => x.isInbox).firstOrNull?.id ??
                  lists.firstOrNull?.id);
    final canCreate =
        listId != null && (!_titled || _title.text.trim().isNotEmpty);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: MaxWidth(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_several) ...[
                SegmentedButton<_Shape>(
                  segments: [
                    ButtonSegment(
                      value: _Shape.perLine,
                      label: Text(
                        l.noteTodoPerLine,
                        key: const Key('todo-shape-lines'),
                      ),
                    ),
                    ButtonSegment(
                      value: _Shape.withSubtasks,
                      label: Text(
                        l.noteTodoWithSubtasks,
                        key: const Key('todo-shape-subtasks'),
                      ),
                    ),
                  ],
                  selected: {_shape},
                  onSelectionChanged: (s) => setState(() => _shape = s.single),
                ),
                const SizedBox(height: 12),
              ],
              if (_titled)
                TextField(
                  key: const Key('todo-title'),
                  controller: _title,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(labelText: l.tasksTitleHint),
                ),
              if (_several && _shape == _Shape.perLine)
                for (final (i, c) in widget.candidates.indexed)
                  ListTile(
                    key: Key('todo-line-$i'),
                    dense: true,
                    leading: const Icon(Icons.task_alt, size: 18),
                    title: Text(c.title),
                  ),
              if (_several && _shape == _Shape.withSubtasks)
                for (final c in widget.candidates.skip(1))
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.subdirectory_arrow_right, size: 18),
                    title: Text(c.title),
                  ),
              if (widget.wholeNote?.checklist.isNotEmpty ?? false)
                SwitchListTile(
                  key: const Key('todo-checklist-subtasks'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.noteTodoChecklistSubtasks),
                  value: _checklistAsSubtasks,
                  onChanged: (v) => setState(() => _checklistAsSubtasks = v),
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const Key('todo-list'),
                initialValue: listId,
                decoration: InputDecoration(labelText: l.tasksList),
                items: [
                  for (final list in lists)
                    DropdownMenuItem(value: list.id, child: Text(list.name)),
                ],
                onChanged: (v) => setState(() => _listId = v),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  InputChip(
                    key: const Key('todo-due'),
                    avatar: const Icon(Icons.event_outlined, size: 18),
                    label: Text(
                      _dueAt == null ? l.tasksNoDue : dateLabel(locale, _dueAt!),
                    ),
                    onPressed: () => unawaited(_pickDue()),
                    onDeleted: _dueAt == null
                        ? null
                        : () => setState(() => _dueAt = null),
                  ),
                  for (final (value, label) in [
                    (0, l.priorityNone),
                    (1, l.priorityLow),
                    (2, l.priorityMedium),
                    (3, l.priorityHigh),
                  ])
                    ChoiceChip(
                      key: Key('todo-priority-$value'),
                      label: Text(label),
                      selected: _priority == value,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _priority = value),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('todo-create'),
                onPressed: canCreate
                    ? () => Navigator.pop(
                        context,
                        MakeTodoResult(
                          tasks: _drafts(),
                          listId: listId,
                          dueAt: _dueAt,
                          priority: _priority,
                        ),
                      )
                    : null,
                child: Text(l.noteTodoCreate),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

`tasksTitleHint` ("Title") and `tasksList` ("List") already exist. `DropdownButtonFormField.initialValue` is the current name; if analyze flags it, use `value:`.

- [ ] **Step 5: Run to verify pass**

Run: `flutter test test/features/notes/make_todo_sheet_test.dart`
Expected: all pass. `dart format lib test && flutter analyze` clean.

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/notes/ui/make_todo_sheet.dart app/lib/l10n app/test/features/notes/make_todo_sheet_test.dart
git commit -m "feat(app): add the sheet that turns note text into tasks"
```

---

### Task 7: Wire make-todo into the note screen

**Files:**
- Modify: `app/lib/features/notes/ui/markdown/note_format_toolbar.dart`
- Modify: `app/lib/features/notes/ui/note_detail_screen.dart`
- Test: `app/test/features/notes/note_detail_screen_test.dart`

**Interfaces:**
- Consumes: everything above; `tasksRepositoryProvider`, `subtasksRepositoryProvider` (`tasks_providers.dart`); `TasksRepository.create/delete`, `SubtasksRepository.add`.
- Produces: toolbar params `onMakeTodo` (`VoidCallback`) and `onOpenTask` (`ValueChanged<String>`); button keys `md-make-todo`, `md-open-task`; whole-note row key `note-make-todo`; read-view menu item keys `read-menu-make-todo`, `read-menu-open-task`, `read-menu-edit`; body context-menu item label `noteMakeTodo`; shortcut Ctrl/Cmd+Shift+T.

- [ ] **Step 1: Write the failing tests**

Add to `note_detail_screen_test.dart`:

```dart
  Future<List<Task>> liveTasks(TestApp app) async => [
    for (final t in await app.db.select(app.db.tasks).get())
      if (t.deletedAt == null) t,
  ];

  appTest('make todo from a checklist line creates the task and links it', (
    tester,
  ) async {
    final app = await pumpApp(tester, initialLocation: '/notes/n1');
    await app.seedList('l1', 'Kitchen');
    await app.seedNote('n1', 'l1', title: 'Shop', body: '- [ ] milk\nbread');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('note-body')));
    await tester.pumpAndSettle();
    bodyField(tester).controller!.selection =
        const TextSelection.collapsed(offset: 3);
    await tester.pump();
    await scrollToolbar(tester, find.byKey(const Key('md-make-todo')));
    await tester.tap(find.byKey(const Key('md-make-todo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-create')));
    await tester.pumpAndSettle();

    final task = (await liveTasks(app)).single;
    expect(task.title, 'milk');
    expect(task.listId, 'l1');
    final note = await app.container.read(notesRepositoryProvider).watch('n1').first;
    expect(note!.body, '- [ ] milk [→ task](nemo://task/${task.id})\nbread');
    expect(find.text('Task created'), findsOneWidget);

    // Now linked: the button offers the task instead.
    await tester.tap(find.byKey(const Key('note-body')));
    await tester.pumpAndSettle();
    bodyField(tester).controller!.selection =
        const TextSelection.collapsed(offset: 3);
    await tester.pump();
    await scrollToolbar(tester, find.byKey(const Key('md-open-task')));
    expect(find.byKey(const Key('md-make-todo')), findsNothing);
  });

  appTest('undo deletes the tasks and takes the links out', (tester) async {
    final app = await pumpApp(tester, initialLocation: '/notes/n1');
    await app.seedList('l1', 'Kitchen');
    await app.seedNote('n1', 'l1', title: 'Shop', body: 'milk\nbread');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('note-body')));
    await tester.pumpAndSettle();
    bodyField(tester).controller!.selection =
        const TextSelection(baseOffset: 0, extentOffset: 10);
    await tester.pump();
    await scrollToolbar(tester, find.byKey(const Key('md-make-todo')));
    await tester.tap(find.byKey(const Key('md-make-todo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-create')));
    await tester.pumpAndSettle();
    expect(await liveTasks(app), hasLength(2));
    expect(find.text('2 tasks created'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(await liveTasks(app), isEmpty);
    final note = await app.container.read(notesRepositoryProvider).watch('n1').first;
    expect(note!.body, 'milk\nbread');
  });

  appTest('make todo from the whole note carries its checklist', (
    tester,
  ) async {
    final app = await pumpApp(tester, initialLocation: '/notes/n1');
    await app.seedList('l1', 'Kitchen');
    await app.seedNote('n1', 'l1', title: 'Shop', body: 'Sunday\n- [ ] milk');
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('note-make-todo')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('note-make-todo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-create')));
    await tester.pumpAndSettle();

    final task = (await liveTasks(app)).single;
    expect(task.title, 'Shop');
    expect(task.notes, 'Sunday');
    final subs = await app.db.select(app.db.subtasks).get();
    expect(subs.single.title, 'milk');
    final note = await app.container.read(notesRepositoryProvider).watch('n1').first;
    expect(note!.body, 'Sunday\n- [ ] milk\n[→ task](nemo://task/${task.id})');
  });

  appTest('long-press in the read view makes a todo of the line, and the '
      'chip opens the task', (tester) async {
    final app = await pumpApp(tester, initialLocation: '/notes/n1');
    await app.container.read(kvStoreProvider).set('notes.readView', '1');
    await app.seedList('l1', 'Kitchen');
    await app.seedNote('n1', 'l1', title: 'Shop', body: 'intro\ncall Bob');
    await tester.pumpAndSettle();

    await tester.longPress(find.byKey(const Key('read-line-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('read-menu-make-todo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('todo-create')));
    await tester.pumpAndSettle();

    final task = (await liveTasks(app)).single;
    expect(task.title, 'call Bob');
    await tester.tap(find.byKey(Key('task-link-chip-${task.id}')));
    await tester.pumpAndSettle();
    expect(app.router.state.uri.path, '/tasks/${task.id}');
  });
```

(`Task` comes from `package:nemo_core/nemo_core.dart`, already imported. If `app.router.state` is not available in this go_router version, use `app.router.routerDelegate.currentConfiguration.uri.path`.)

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/notes/note_detail_screen_test.dart`
Expected: the four new tests fail (`md-make-todo` / `note-make-todo` / `read-menu-make-todo` not found).

- [ ] **Step 3: Toolbar**

In `note_format_toolbar.dart` add the import `import 'package:nemo/features/notes/ui/markdown/note_to_task.dart';`, the fields

```dart
  /// Turns what the cursor or selection is on into a task.
  final VoidCallback onMakeTodo;

  /// Opens the task linked on the cursor's line.
  final ValueChanged<String> onOpenTask;
```

as required constructor params, and inside the `ListenableBuilder` builder, after `final undo = ...`:

```dart
                final value = controller.value;
                final linkedTask = value.selection.isValid
                    ? linkedTaskAt(value.text, value.selection.start)
                    : null;
                final canMakeTodo = todoCandidates(value).isNotEmpty;
```

and after the `md-checkbox` button:

```dart
                    if (linkedTask != null)
                      button(
                        'md-open-task',
                        Icons.open_in_new,
                        l.noteOpenTask,
                        () => onOpenTask(linkedTask),
                      )
                    else
                      button(
                        'md-make-todo',
                        Icons.add_task,
                        l.noteMakeTodo,
                        canMakeTodo ? onMakeTodo : null,
                      ),
```

- [ ] **Step 4: Screen**

Imports in `note_detail_screen.dart`:

```dart
import 'package:nemo/features/notes/ui/make_todo_sheet.dart';
import 'package:nemo/features/notes/ui/markdown/note_to_task.dart';
import 'package:nemo/features/tasks/ui/tasks_providers.dart';
```

Methods:

```dart
  void _openTask(String id) => unawaited(context.push(Routes.task(id)));

  Future<void> _makeTodoFromEditor() async {
    final candidates = todoCandidates(_body.value);
    if (candidates.isEmpty) return;
    await _makeTodo(candidates: candidates);
  }

  Future<void> _makeTodoFromNote(Note note) async {
    await _save();
    if (!mounted) return;
    await _makeTodo(wholeNote: wholeNoteTodo(_title.text, _body.text));
  }

  /// Asks, creates the tasks, links them in the body and offers undo.
  /// A failure part way deletes what was created and leaves the body as
  /// it was.
  Future<void> _makeTodo({
    List<TodoCandidate> candidates = const [],
    WholeNoteTodo? wholeNote,
  }) async {
    final note = ref.read(noteByIdProvider(widget.noteId)).value;
    if (note == null) return;
    final result = await showMakeTodoSheet(
      context,
      candidates: candidates,
      wholeNote: wholeNote,
      listId: note.listId,
    );
    if (result == null || !mounted) return;
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final tasks = ref.read(tasksRepositoryProvider);
    final subtasks = ref.read(subtasksRepositoryProvider);
    final created = <String>[];
    try {
      for (final draft in result.tasks) {
        final task = await tasks.create(
          listId: result.listId,
          title: draft.title,
          notes: draft.notes,
          dueAt: result.dueAt,
          priority: result.priority,
        );
        created.add(task.id);
        for (final sub in draft.subtasks) {
          await subtasks.add(task.id, sub);
        }
      }
    } on Object catch (error, stack) {
      debugPrint('note ${widget.noteId}: tasks not created: $error\n$stack');
      for (final id in created) {
        await tasks.delete(id);
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.noteTodoFailed)));
      return;
    }
    if (!mounted) return;
    final body = _body.text;
    final linked = wholeNote != null
        ? appendTaskLink(body, created.single)
        : insertTaskLinks(body, [
            // One draft per candidate, or one task anchored at the first.
            if (created.length == candidates.length)
              for (final (i, id) in created.indexed) (candidates[i].anchor, id)
            else
              (candidates.first.anchor, created.single),
          ]);
    await _writeBody(linked);
    if (!mounted) return;
    // A SnackBar has one action: Undo takes it, and Open (one task only)
    // sits in the content.
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Expanded(child: Text(l.noteTodoCreated(created.length))),
              if (created.length == 1)
                TextButton(
                  key: const Key('todo-open'),
                  onPressed: () {
                    messenger.hideCurrentSnackBar();
                    _openTask(created.single);
                  },
                  child: Text(l.commonOpen),
                ),
            ],
          ),
          action: SnackBarAction(
            label: l.commonUndo,
            onPressed: () => unawaited(_undoTodo(created.toSet())),
          ),
        ),
      );
  }
```

Add:

```dart
  Future<void> _undoTodo(Set<String> ids) async {
    final tasks = ref.read(tasksRepositoryProvider);
    for (final id in ids) {
      await tasks.delete(id);
    }
    if (!mounted) return;
    await _writeBody(removeTaskLinks(_body.text, ids));
  }

  Future<void> _onLongPressLine(int lineStart, Offset at) async {
    final body = _body.text;
    final linked = linkedTaskAt(body, lineStart);
    final candidate = linked == null ? lineCandidate(body, lineStart) : null;
    final l = L.of(context);
    final choice = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(at.dx, at.dy, at.dx, at.dy),
      items: [
        if (linked != null)
          PopupMenuItem(
            key: const Key('read-menu-open-task'),
            value: 'open',
            child: Text(l.noteOpenTask),
          )
        else if (candidate != null)
          PopupMenuItem(
            key: const Key('read-menu-make-todo'),
            value: 'todo',
            child: Text(l.noteMakeTodo),
          ),
        PopupMenuItem(
          key: const Key('read-menu-edit'),
          value: 'edit',
          child: Text(l.commonEdit),
        ),
      ],
    );
    if (!mounted) return;
    switch (choice) {
      case 'open':
        _openTask(linked!);
      case 'todo':
        await _makeTodo(candidates: [candidate!]);
      case 'edit':
        _editAt(lineStart);
    }
  }
```

In `build`:

- `NoteReadView(... onLongPressLine: (start, at) => unawaited(_onLongPressLine(start, at)), ...)`.
- Add to the `CallbackShortcuts` bindings:

```dart
                        SingleActivator(
                          LogicalKeyboardKey.keyT,
                          control: !useMeta,
                          meta: useMeta,
                          shift: true,
                        ): () =>
                            unawaited(_makeTodoFromEditor()),
```

- On the body `TextField`, add:

```dart
                        contextMenuBuilder: (context, state) {
                          final items = [...state.contextMenuButtonItems];
                          if (!state.textEditingValue.selection.isCollapsed) {
                            items.insert(
                              0,
                              ContextMenuButtonItem(
                                label: l.noteMakeTodo,
                                onPressed: () {
                                  state.hideToolbar();
                                  unawaited(_makeTodoFromEditor());
                                },
                              ),
                            );
                          }
                          return AdaptiveTextSelectionToolbar.buttonItems(
                            anchors: state.contextMenuAnchors,
                            buttonItems: items,
                          );
                        },
```

- Between `NoteListPicker(note: note),` and `NoteDeleteAction(note: note),`:

```dart
                    ListTile(
                      key: const Key('note-make-todo'),
                      leading: const Icon(Icons.add_task),
                      title: Text(l.noteMakeTodoFromNote),
                      onTap: () => unawaited(_makeTodoFromNote(note)),
                    ),
```

- `NoteFormatToolbar(... onMakeTodo: () => unawaited(_makeTodoFromEditor()), onOpenTask: _openTask)`.

Opening the sheet takes focus from the body, so its blur save runs first; `_makeTodo` reads `_body.text` only after the sheet returns, and writes through `_writeBody`, so the links land as one edit even with the body unfocused.

- [ ] **Step 5: Run to verify pass**

Run: `flutter test test/features/notes`
Expected: all pass. `dart format lib test && flutter analyze` clean.

- [ ] **Step 6: Commit**

```bash
git add app/lib/features/notes/ui app/test/features/notes/note_detail_screen_test.dart
git commit -m "feat(app): turn note lines, selections and whole notes into linked tasks"
```

---

### Task 8: Changelog and full verification

**Files:**
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Changelog**

Under the intro paragraphs and above `## 0.11.1 - 2026-09-23`, add (or extend an existing `## Unreleased`):

```markdown
## Unreleased

### Added

- A note can switch between its markdown and a formatted read view with
  the button in its top right corner; the choice is remembered. In the
  read view checkboxes can be ticked, links open, and tapping the text
  goes back to editing on that line.
- Note text can become a todo: select text or put the cursor on a list
  line and tap the new toolbar button (or Ctrl+Shift+T), long-press a line
  in the read view, or use "Make todo from note" at the bottom of a note.
  Several lines become one task each or one task with subtasks. The note
  keeps its text and links to each task, showing whether it is done.
```

- [ ] **Step 2: Full check**

Run, one at a time:

```bash
dart format --set-exit-if-changed lib test
flutter analyze
flutter test --concurrency=2 test/features/notes
flutter test --concurrency=2 test/features/tasks
flutter test --concurrency=2
```

Expected: format unchanged, analyze "No issues found!", all tests pass. Check the pass count of the full run against the number before this branch (`git stash` is not needed: compare with the count printed on `main`, or note it in the report).

- [ ] **Step 3: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs: note read view and make-todo in the changelog"
```
