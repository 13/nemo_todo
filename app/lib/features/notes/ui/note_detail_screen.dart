import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/core/widgets/app_icon.dart';
import 'package:nemo/core/widgets/max_width.dart';
import 'package:nemo/features/notes/data/notes_repository.dart';
import 'package:nemo/features/notes/ui/make_todo_chip.dart';
import 'package:nemo/features/notes/ui/make_todo_sheet.dart';
import 'package:nemo/features/notes/ui/markdown/markdown_editing_controller.dart';
import 'package:nemo/features/notes/ui/markdown/note_format_toolbar.dart';
import 'package:nemo/features/notes/ui/markdown/note_to_task.dart';
import 'package:nemo/features/notes/ui/note_body_editor.dart';
import 'package:nemo/features/notes/ui/note_editor_sections.dart';
import 'package:nemo/features/notes/ui/note_read_view.dart';
import 'package:nemo/features/notes/ui/note_tips.dart';
import 'package:nemo/features/notes/ui/notes_providers.dart';
import 'package:nemo/features/notes/ui/task_link_chip.dart';
import 'package:nemo/features/photos/ui/photo_strip.dart';
import 'package:nemo/features/tasks/data/tasks_repository.dart';
import 'package:nemo/features/tasks/ui/tasks_providers.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/router.dart';
import 'package:nemo_core/nemo_core.dart';

part 'note_detail_saving.dart';
part 'note_detail_tips.dart';
part 'note_detail_todos.dart';

/// Title and body of one note. A note always opens as a page -- unlike a
/// task it never sits in the wide-window detail pane -- so there is no
/// `embedded` flag to plumb through here.
class NoteDetailScreen extends ConsumerStatefulWidget {
  const NoteDetailScreen({required this.noteId, super.key});

  final String noteId;

  @override
  ConsumerState<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends ConsumerState<NoteDetailScreen>
    with _NoteSaving, _NoteTipsShown, _NoteTodos {
  @override
  final _title = TextEditingController();
  @override
  final _body = MarkdownEditingController();
  final _undo = UndoHistoryController();
  @override
  final _titleFocus = FocusNode();
  @override
  final _bodyFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _repo = ref.read(notesRepositoryProvider);
    _tips = NoteTips(ref.read(kvStoreProvider));
    _titleFocus.addListener(_onFocusChange);
    _bodyFocus.addListener(_onFocusChange);
    _body
      // A listener, not `onChanged`: toolbar buttons and shortcuts write
      // `_body.value` directly, which `onChanged` never hears about.
      ..addListener(_onBodyChanged)
      // Selection-only changes are exactly what `_onBodyChanged` ignores
      // (it only cares about text), so the selection tip needs a listener
      // of its own.
      ..addListener(_checkSelectionTip);
  }

  // The mode chosen on this page, which wins over the stored preference
  // from the first toggle on: the preference's stream answers a frame or
  // more after the write, and the page must switch at once. Null until
  // then, when the preference decides -- except for an empty note, which
  // opens in the editor since there is nothing to read.
  bool? _readView;
  bool? _openedEmpty;

  @override
  void dispose() {
    _flushOnDispose();
    _title.dispose();
    _body.dispose();
    _undo.dispose();
    // Leaving with the body focused never reports the blur.
    if (_browserMenuOff) setBrowserContextMenuEnabled(enabled: true);
    _titleFocus.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  /// Shared by both focus nodes. Losing focus saves -- and either way, a
  /// field that only ever had focus (never an edit) may need to catch up
  /// to a note that changed while it was watching from the sidelines;
  /// `setState` forces the rebuild that lets `_fill` do that.
  void _onFocusChange() {
    _syncBrowserContextMenu();
    if (_titleFocus.hasFocus || _bodyFocus.hasFocus) return;
    unawaited(_save());
    if (mounted) setState(() {});
  }

  // Whether this page has turned the browser's context menu off. Tracked
  // rather than toggled on every focus change: the title's focus changes
  // run through the same listener, and must not touch it.
  bool _browserMenuOff = false;

  /// Off while the body has focus, on otherwise -- see
  /// [setBrowserContextMenuEnabled].
  void _syncBrowserContextMenu() {
    final off = _bodyFocus.hasFocus;
    if (off == _browserMenuOff) return;
    _browserMenuOff = off;
    setBrowserContextMenuEnabled(enabled: !off);
  }

  // Shared by the Ctrl/Cmd+K shortcut and the toolbar's `md-link` button,
  // so both open the same dialog against this screen's own, stable
  // context and focus node -- see `NoteFormatToolbar.onInsertLink`.
  void _insertLink() =>
      unawaited(promptForLink(context, _body, focusNode: _bodyFocus));

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
  @override
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
  /// the read view, task links from make-todo. [selection], when given, is
  /// where the cursor goes; otherwise it stays where it was.
  @override
  Future<bool> _writeBody(String body, {TextSelection? selection}) {
    final sel = selection ?? _body.selection;
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

  @override
  void _openTask(String id) => unawaited(context.push(Routes.task(id)));

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
    final readView = _showReadView(note);
    if (readView) _checkReadHint();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        // A failed write keeps the page open, its snackbar showing: leaving
        // would leave the text to `dispose`'s one unannounced retry.
        if (!await _save()) return;
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
        appBar: AppBar(
          actions: [
            IconButton(
              key: const Key('note-view-toggle'),
              tooltip: readView ? l.noteEditToggle : l.noteReadToggle,
              icon: AppIcon(
                readView ? Icons.edit_outlined : Icons.visibility_outlined,
              ),
              onPressed: () => unawaited(_setReadView(!readView)),
            ),
            NotePinAction(note: note),
          ],
        ),
        // The toolbar sits in the body, under the scrolling content: the
        // body is what the keyboard shrinks, so the bar rides directly on
        // top of it. `bottomNavigationBar` would stay behind the keyboard.
        body: Column(
          children: [
            Expanded(
              // The chip floats over the page's bottom-right corner, just
              // above the format toolbar, rather than taking a row of its
              // own that would push the page up and down as it comes and
              // goes.
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MaxWidth(
                    child: ListView(
                      // Room at the end for the Make todo chip, which floats
                      // over the page's last 56 px: the last rows can still
                      // be scrolled out from under it.
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 64),
                      children: [
                        TextField(
                          key: const Key('note-title'),
                          controller: _title,
                          focusNode: _titleFocus,
                          maxLines: null,
                          textCapitalization: TextCapitalization.sentences,
                          onChanged: (_) {
                            _titleDirty = true;
                            _scheduleSave();
                          },
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                          decoration: InputDecoration(
                            hintText: l.noteTitleHint,
                            filled: false,
                            border: InputBorder.none,
                            // A finger's height, however tight the style's
                            // field padding.
                            constraints: const BoxConstraints(
                              minHeight: kMinInteractiveDimension,
                            ),
                          ),
                        ),
                        if (readView) ...[
                          if (_showReadHint)
                            ReadViewHint(
                              onClose: () =>
                                  setState(() => _showReadHint = false),
                            ),
                          NoteReadView(
                            key: const Key('note-read-view'),
                            body: _body.text,
                            onChanged: (body) => unawaited(_writeBody(body)),
                            onEditAt: _editAt,
                            onLongPressLine: (start, at) =>
                                unawaited(_onLongPressLine(start, at)),
                            onOpenLink: (url) =>
                                openNoteLink(context, ref, url),
                            taskChip: (id) => TaskLinkChip(taskId: id),
                          ),
                        ] else
                          NoteBodyEditor(
                            controller: _body,
                            focusNode: _bodyFocus,
                            undoController: _undo,
                            onInsertLink: _insertLink,
                            onMakeTodo: () => unawaited(_makeTodoFromEditor()),
                          ),
                        const SizedBox(height: 16),
                        PhotoStrip(
                          parentKind: PhotoParent.note,
                          parentId: note.id,
                        ),
                        NoteListPicker(note: note),
                        ListTile(
                          key: const Key('note-make-todo'),
                          leading: const AppIcon(Icons.add_task),
                          title: Text(l.noteMakeTodoFromNote),
                          onTap: () => unawaited(_makeTodoFromNote()),
                        ),
                        NoteDeleteAction(note: note),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 16,
                    bottom: 8,
                    child: ListenableBuilder(
                      listenable: _bodyFocus,
                      builder: (_, _) => !readView && _bodyFocus.hasFocus
                          ? MakeTodoChip(
                              controller: _body,
                              onMakeTodo: () =>
                                  unawaited(_makeTodoFromEditor()),
                              onOpenTask: _openTask,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
            ),
            ListenableBuilder(
              listenable: _bodyFocus,
              builder: (_, _) => _bodyFocus.hasFocus
                  ? NoteFormatToolbar(
                      controller: _body,
                      undoController: _undo,
                      onInsertLink: _insertLink,
                      onMakeTodo: () => unawaited(_makeTodoFromEditor()),
                      onOpenTask: _openTask,
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
