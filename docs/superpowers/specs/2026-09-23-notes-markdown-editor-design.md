# Notes: live markdown editor

## Goal

A note's body should be editable in place, with no read/edit toggle, and
come with a formatting toolbar for bold, italic, strikethrough, headings,
lists, checkboxes, quotes, code and links. What is stored does not change:
`Note.body` is still the markdown the person typed. UI only -- the model,
database, sync, server and export are untouched.

## Decisions

| Topic | Decision |
|---|---|
| Editing | Body is always a `TextField`; the pencil toggle and read mode go away. No autofocus -- the keyboard appears on tap |
| Look while typing | Live-styled markdown: syntax painted in place (bold is bold, headings are big, `~~x~~` is struck) with the markers drawn faint, never hidden |
| Storage | Unchanged plain markdown string. No document model, no conversion |
| Styling mechanism | `MarkdownEditingController extends TextEditingController`, overriding `buildTextSpan`. Text is only painted, never rewritten, so cursor, selection, IME and undo stay native |
| Parser | Own small line-based parser producing styled character ranges. The `markdown` package's AST drops source offsets, which this needs exactly |
| Toolbar | Horizontal scrolling strip pinned to the bottom of the page, riding above the soft keyboard, shown only while the body has focus |
| Shortcuts | Ctrl/Cmd+B bold, +I italic, +Shift+X strike, +K link |
| Lists | Enter on a list line continues it; Enter on an empty item ends the list |
| Checkboxes | Toolbar checkbox button on a `- [ ]` line flips it to `- [x]` and back; on any other line it prefixes `- [ ] ` |
| Links | Tapping text only places the cursor. With the cursor inside `[text](url)` the toolbar shows "Open link", using `openUrlProvider` and the existing http/https-only rule |
| Saving | Existing rule (on unfocus and on pop, never overwrite a focused field) plus a 1 s debounce after typing stops, since there is no longer a "Done" tap to mark the end of an edit |
| Removed | `NoteBodyView`, its test, and the `flutter_markdown_plus` dependency (its only user). l10n keys `noteEditToggle`, `noteReadToggle` |
| Card previews | Unchanged: raw markdown source |

## Why this shape

A true WYSIWYG editor (flutter_quill, appflowy_editor, super_editor) would
hide the markers entirely, but it needs its own document model and a
markdown conversion on every load and save. Those round trips are lossy --
blank lines, list markers and emphasis spellings get normalised -- and
every normalisation is a write that syncs, so two devices merely opening a
note could fight over it. The notes design ruled out a rich-text model for
exactly this reason, and it still holds.

Painting the raw text keeps every property the plain string has: search
greps it, export writes it, merge is last-write-wins on it, and what is on
screen is character-for-character what is stored. Markers stay visible but
faint because hiding them makes the painted text shorter than the real
text, and then cursor positions, selection handles and taps no longer line
up.

## Components

All new files live in `app/lib/features/notes/ui/markdown/`.

### `markdown_spans.dart` -- parser (pure Dart)

```dart
enum MdStyle { h1, h2, h3, h4, h5, h6, bold, italic, strike, code,
  codeBlock, quote, link, marker, listMarker, taskDone }

class MdRange {
  const MdRange(this.start, this.end, this.style);
  final int start; // inclusive, UTF-16 offset into the body
  final int end;   // exclusive
  final MdStyle style;
}

List<MdRange> parseMarkdownRanges(String text);
```

Block rules, per line:

- `#`..`######` + space: heading style over the line, the hashes as `marker`.
- `> `: `quote` over the line, `>` as `marker`.
- `- `, `* `, `+ `, `1. `: bullet or number as `listMarker`.
- `- [ ] ` / `- [x] ` (also `X`): box as `listMarker`; a checked line's
  content gets `taskDone`.
- A line of three or more `-`, `*` or `_`: `marker` (horizontal rule).
- ```` ``` ```` fences: everything from the opening fence to the closing
  fence (or end of text if unclosed) is `codeBlock`; no inline parsing
  inside.

Inline rules, on non-code lines, left to right:

- `` `code` `` first; nothing inside it is parsed further.
- `**bold**`/`__bold__`, `*italic*`/`_italic_`, `~~strike~~`. Delimiters
  are `marker`. An unclosed delimiter is plain text. Nesting
  (`**bold *and italic***`) is supported one level deep. `_` inside a word
  (`snake_case`) is not emphasis.
- `[text](url)`: `text` is `link`, the brackets and `(url)` are `marker`.

Inline spans never cross a line break.

### `markdown_editing_controller.dart`

`MarkdownEditingController extends TextEditingController`. `buildTextSpan`
calls `parseMarkdownRanges(text)`, merges overlapping ranges into flat
`TextSpan` children, and maps each `MdStyle` to a `TextStyle` derived from
the passed-in base style and `Theme`:

- headings: `headlineSmall` .. `titleSmall` sizes, bold.
- bold / italic / strike: weight, style, `TextDecoration.lineThrough`.
- code / codeBlock: monospace, `surfaceContainerHighest` background.
- quote: italic, `onSurfaceVariant`.
- link: `primary`, underlined.
- marker / listMarker: `onSurfaceVariant` at reduced opacity (listMarker
  slightly stronger than marker, so bullets stay readable).
- taskDone: struck through and muted.

The IME composing range keeps its underline on top of the markdown style,
the same way the base implementation does it.

Parsing is linear in the body length and runs per build; notes are small
enough that caching is not needed. If profiling says otherwise, cache on
`text` identity.

### `markdown_commands.dart` -- edits (pure functions)

Each takes a `TextEditingValue` and returns a new one, so every command is
unit-testable without widgets:

```dart
TextEditingValue toggleInline(TextEditingValue v, String marker); // ** _ ~~ `
TextEditingValue toggleLinePrefix(TextEditingValue v, String prefix); // "> ", "- ", "1. "
TextEditingValue cycleHeading(TextEditingValue v); // none → # → ## → ### → none
TextEditingValue toggleCheckbox(TextEditingValue v);
TextEditingValue toggleCodeBlock(TextEditingValue v);
TextEditingValue insertLink(TextEditingValue v, String url);
TextEditingValue? continueList(TextEditingValue v); // null = not a list line
String? linkAtCursor(TextEditingValue v);
```

- `toggleInline`: with a selection, wraps it, or unwraps if the selection
  is already wrapped (markers inside or immediately outside the
  selection). With a collapsed cursor, inserts `marker+marker` and puts the
  cursor between them.
- `toggleLinePrefix`: applies to every line the selection touches. If all
  of them already carry the prefix it is removed, otherwise added. Numbered
  lists number `1.`, `2.`, ... in order.
- `toggleCheckbox`: on `- [ ] ` / `- [x] ` flips the box; on a plain `- `
  line turns it into `- [ ] `; otherwise prefixes `- [ ] `.
- `toggleCodeBlock`: wraps the selected lines in ```` ``` ```` fences, or
  removes fences surrounding the cursor.
- `insertLink`: `[selection](url)`, or `[url](url)` with no selection.
- `continueList`: called on Enter. On a list or task line with content,
  inserts a newline plus the same prefix (numbers incremented, boxes
  unchecked). On an item with no content, removes the prefix and inserts
  nothing -- ending the list.

Every command produces a single `TextEditingValue` change, so the
field's native undo takes it back in one step.

### `note_format_toolbar.dart`

`NoteFormatToolbar({required TextEditingController controller, required
UndoHistoryController undoController})`. A `Material` bar with a horizontally scrolling row
of `IconButton`s, each with a tooltip and key `md-<action>`:

bold, italic, strike, heading, bullet, numbered, checkbox, quote, code,
code block, link, and -- only when `linkAtCursor` finds an http or https
URL -- open link.
Undo and redo via an `UndoHistoryController` shared with the field.

Buttons must not steal focus from the body: they use
`canRequestFocus: false` / `focusNode` skipping, and the command writes
straight to `controller.value`. The link button opens a small dialog with a
URL field; cancelling changes nothing.

## Screen changes

`note_detail_screen.dart`:

- `_body` becomes a `MarkdownEditingController`; `_editing` and
  `_toggleEditing` go, as does the pencil `IconButton`.
- The body `TextField` is always present (`key: note-body`, `minLines: 6`),
  a shared `UndoHistoryController` (`undoController:`), and a
  `Shortcuts`/`Actions` pair for the key bindings. Enter handling uses a
  `TextInputFormatter` on the field rather than a key listener, so it
  works with soft keyboards and IME too: when the new
  value differs from the old by a single inserted `\n` at the cursor, the
  formatter substitutes `continueList(old)` if it returns non-null.
- The page body becomes a `Column`: the scrolling `ListView` in an
  `Expanded`, then the toolbar inside a `ListenableBuilder` on
  `_bodyFocus`, returning `SizedBox.shrink()` when unfocused. The body is
  what `resizeToAvoidBottomInset` shrinks, so the bar sits directly above
  the keyboard; `Scaffold.bottomNavigationBar` would stay behind it.
- The toolbar is wrapped in `TextFieldTapRegion`, so a mouse click on it
  (web, desktop) is not a tap outside the body and does not unfocus it.
- A `Timer` restarted on every body or title change calls `_save()` after
  1 s. It is cancelled in `dispose` and before the unfocus/pop saves, which
  still run as today. `_fill` still refuses to overwrite a focused field.

## Localisation

Remove `noteEditToggle`, `noteReadToggle` from `app_en.arb`, `app_de.arb`,
`app_it.arb`. Add:

| Key | en | de | it |
|---|---|---|---|
| `mdBold` | Bold | Fett | Grassetto |
| `mdItalic` | Italic | Kursiv | Corsivo |
| `mdStrike` | Strikethrough | Durchgestrichen | Barrato |
| `mdHeading` | Heading | Überschrift | Titolo |
| `mdBulletList` | Bulleted list | Aufzählung | Elenco puntato |
| `mdNumberedList` | Numbered list | Nummerierte Liste | Elenco numerato |
| `mdChecklist` | Checkbox | Kontrollkästchen | Casella di controllo |
| `mdQuote` | Quote | Zitat | Citazione |
| `mdCode` | Code | Code | Codice |
| `mdCodeBlock` | Code block | Codeblock | Blocco di codice |
| `mdLink` | Link | Link | Link |
| `mdLinkUrlHint` | URL | URL | URL |
| `mdOpenLink` | Open link | Link öffnen | Apri link |
| `mdUndo` | Undo | Rückgängig | Annulla |
| `mdRedo` | Redo | Wiederholen | Ripeti |

## Testing

**Parser** (`test/features/notes/markdown/markdown_spans_test.dart`): each
heading level; bold/italic/strike with both spellings; one level of
nesting; unclosed delimiters staying plain; intraword `_`; inline code
shielding its contents; links; quotes; bullet, numbered and task lines,
checked lines getting `taskDone`; fenced block, including unclosed; no
inline span crossing a newline; offsets correct with non-ASCII text
(emoji, umlauts).

**Commands** (`markdown_commands_test.dart`): wrap, unwrap, and empty-
selection insert for each inline marker; line prefix add/remove over a
multi-line selection and mixed selections; numbered renumbering; heading
cycle; checkbox flip and promotion; code block wrap/unwrap; link with and
without selection; `continueList` for bullet, number (incremented), task
(unchecked) and empty-item exit; `linkAtCursor` inside, on the edge of and
outside a link.

**Controller** (`markdown_editing_controller_test.dart`): `buildTextSpan`
over a sample body yields spans whose concatenated text equals the input
exactly and whose styles match the ranges.

**Screen** (`note_detail_screen_test.dart`, updated): body editable with no
toggle; toolbar absent until the body is focused and gone after unfocus;
Bold button wraps the selection and keeps focus on the body; Ctrl+B does
the same; checkbox button flips `- [ ]`; Enter continues a bullet list;
"Open link" appears only with the cursor in a link and opens only
http/https through `openUrlProvider`; the debounce saves to the repository
after 1 s without unfocusing; a sync arriving while focused does not
replace the text.

`note_body_view_test.dart` is deleted with the widget. Coverage floors in
`ci.yml` apply to the new files.

## Out of scope

- Hiding markers (true WYSIWYG) and any rich-text document model.
- Tables, footnotes, inline images; pictures stay in the photo strip.
- Underline and highlight, which markdown does not have.
- A rendered read-only view of the note.
- Tapping a checkbox or link directly in the text.
