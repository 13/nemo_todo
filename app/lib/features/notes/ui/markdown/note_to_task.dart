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
  final bare = line.replaceFirst(_blockPrefix, '').replaceAll(_taskLinkAny, '');
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
    final (ls, le) = _lineAt(text, sel.start);
    if (_linked(text.substring(ls, le))) return const [];
    final title = plainLine(selected);
    return title.isEmpty
        ? const []
        : [TodoCandidate(title: title, anchor: sel.end)];
  }
  final out = <TodoCandidate>[];
  var (ls, _) = _lineAt(text, sel.start);
  // `<`, not `<=`: a selection that ends at the very start of a line --
  // a whole line taken with its line break, or Shift+Down -- does not
  // reach into that line.
  while (ls < sel.end && ls <= text.length) {
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

/// [v] with the links of [insertTaskLinks] in its text, and a collapsed
/// cursor at the old selection's end, shifted past every link inserted at
/// or before it. A cursor at an anchor -- the end of the line it made a
/// task of -- so ends up after the link, where typing (or Enter,
/// continuing the list) belongs, not wedged between the line and its
/// link. Collapsed rather than kept as a range: a selection spanning the
/// text would otherwise grow to cover the new links too, instead of the
/// plain text it was drawn over.
TextEditingValue insertTaskLinksInValue(
  TextEditingValue v,
  List<(int, String)> links,
) {
  int shifted(int offset) {
    if (offset < 0) return offset;
    var out = offset;
    for (final (anchor, id) in links) {
      if (anchor <= offset) out += ' ${taskLink(id)}'.length;
    }
    return out;
  }

  return TextEditingValue(
    text: insertTaskLinks(v.text, links),
    selection: TextSelection.collapsed(offset: shifted(v.selection.end)),
  );
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

/// [v] with the links to [ids] taken out by [removeTaskLinks], a collapsed
/// cursor kept on the same text: shifted left by whatever [removeTaskLinks]
/// took out before it, clamped to the new text's length. Found by running
/// [removeTaskLinks] on the text up to the cursor alone -- whatever that
/// shrinks by is exactly what disappeared ahead of it. A selection that
/// spans text, rather than a plain cursor, is left where it was: there is
/// no single place left to pin one end of it to.
TextEditingValue removeTaskLinksInValue(TextEditingValue v, Set<String> ids) {
  final text = removeTaskLinks(v.text, ids);
  final sel = v.selection;
  if (!sel.isValid || !sel.isCollapsed) {
    return TextEditingValue(text: text, selection: sel);
  }
  final kept = removeTaskLinks(v.text.substring(0, sel.start), ids);
  return TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(
      offset: kept.length.clamp(0, text.length),
    ),
  );
}

/// The whole note as a task: its title, its body as notes, and its open
/// checkboxes as possible subtasks -- with the body minus those lines for
/// when they become subtasks. Task links already in the note are left out
/// of the notes: in a task's notes they would only point at other tasks
/// from a place nobody reads them as links. A line that held nothing but
/// links goes with them.
({
  String title,
  String notes,
  String notesWithoutChecklist,
  List<String> checklist,
})
wholeNoteTodo(String title, String body) {
  final lines = [
    for (final line in body.split('\n'))
      if (!_taskLinkAny.hasMatch(line))
        line
      else if (line.replaceAll(_taskLinkAny, '').trim().isNotEmpty)
        line.replaceAll(_taskLinkAny, ''),
  ];
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
    notes: lines.join('\n'),
    notesWithoutChecklist: kept.join('\n'),
    checklist: checklist,
  );
}
