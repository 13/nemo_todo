import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/sync_writes.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/core/widgets/max_width.dart';
import 'package:nemo/features/notes/data/notes_repository.dart';
import 'package:nemo/features/notes/ui/make_todo_chip.dart';
import 'package:nemo/features/notes/ui/make_todo_sheet.dart';
import 'package:nemo/features/notes/ui/markdown/markdown_commands.dart';
import 'package:nemo/features/notes/ui/markdown/markdown_editing_controller.dart';
import 'package:nemo/features/notes/ui/markdown/note_format_toolbar.dart';
import 'package:nemo/features/notes/ui/markdown/note_to_task.dart';
import 'package:nemo/features/notes/ui/note_editor_sections.dart';
import 'package:nemo/features/notes/ui/note_read_view.dart';
import 'package:nemo/features/notes/ui/notes_providers.dart';
import 'package:nemo/features/notes/ui/task_link_chip.dart';
import 'package:nemo/features/photos/ui/photo_strip.dart';
import 'package:nemo/features/tasks/data/tasks_repository.dart';
import 'package:nemo/features/tasks/ui/tasks_providers.dart';
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

  // Whether a field holds an edit the store hasn't seen yet. `_save` only
  // writes a dirty field; a clean one takes the stored note's value
  // instead. Without this, focusing a field (with no typing) while a sync
  // changes it, then unfocusing, would save the field's stale text over
  // the sync -- `_fill` correctly skips a focused field, but the old text
  // it left behind is otherwise indistinguishable from a real edit.
  bool _titleDirty = false;
  bool _bodyDirty = false;

  // The note a save of ours just replaced, while `noteByIdProvider` may
  // still be holding it: the store's stream lags the write in production
  // (drift's background isolate), so a rebuild in that window -- the one
  // `_onFocusChange` forces, say -- would otherwise have `_fill` copy the
  // pre-write text back into the fields `_save` has just settled. Every
  // write stamps a fresh `updatedAt`, so any note the stream emits after
  // it differs from this one.
  Note? _superseded;

  // Kept for `dispose`, where Riverpod no longer allows `ref`: a page can
  // go without a pop -- on web, browser back and a deep link's `go` are
  // URL changes `PopScope` never hears of -- and whatever is still dirty
  // is written from here then. Refreshed on every save, so it follows the
  // provider if that is ever rebuilt.
  late NotesRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo = ref.read(notesRepositoryProvider);
    _titleFocus.addListener(_onFocusChange);
    _bodyFocus.addListener(_onFocusChange);
    // A listener, not `onChanged`: toolbar buttons and shortcuts write
    // `_body.value` directly, which `onChanged` never hears about.
    _body.addListener(_onBodyChanged);
  }

  String _lastBody = '';

  // The mode chosen on this page, which wins over the stored preference
  // from the first toggle on: the preference's stream answers a frame or
  // more after the write, and the page must switch at once. Null until
  // then, when the preference decides -- except for an empty note, which
  // opens in the editor since there is nothing to read.
  bool? _readView;
  bool? _openedEmpty;

  void _onBodyChanged() {
    if (_body.text == _lastBody) return; // selection-only change
    _lastBody = _body.text;
    // `_fill` writes only while unfocused, so a sync landing is not
    // mistaken for typing.
    if (_bodyFocus.hasFocus) {
      _bodyDirty = true;
      _scheduleSave();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (_titleDirty || _bodyDirty) {
      final title = _title.text.trim();
      unawaited(
        _flush(
          _repo,
          widget.noteId,
          title: _titleDirty && title.isNotEmpty ? title : null,
          body: _bodyDirty ? _body.text : null,
        ),
      );
    }
    _title.dispose();
    _body.dispose();
    _undo.dispose();
    // Leaving with the body focused never reports the blur.
    if (_browserMenuOff) setBrowserContextMenuEnabled(enabled: true);
    _titleFocus.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  /// Keeps the controllers in step with the stored note unless being
  /// edited. Never while a field has focus: an arriving sync would
  /// otherwise move the cursor out from under whoever is typing. A dirty
  /// field is skipped too -- `_save` keeps the flag set for the whole
  /// write, so this stays skipped until the field's text has actually
  /// landed in the store, not just until the write was kicked off.
  /// Skips [_superseded] outright: it is older than what the fields show.
  void _fill(Note note) {
    if (note == _superseded) return;
    _superseded = null;
    if (!_titleFocus.hasFocus && !_titleDirty && _title.text != note.title) {
      _title.text = note.title;
    }
    if (!_bodyFocus.hasFocus && !_bodyDirty && _body.text != note.body) {
      _body.text = note.body;
    }
  }

  /// The last-chance write from [dispose]. A failure here has no page left
  /// to show it on, so it is only logged; there is nothing else to do with
  /// the text once its field is gone.
  static Future<void> _flush(
    NotesRepository repo,
    String id, {
    String? title,
    String? body,
  }) async {
    try {
      await repo.updateText(id, title: title, body: body);
    } on Object catch (error, stack) {
      debugPrint('note $id not saved on leaving: $error\n$stack');
    }
  }

  void _scheduleSave() {
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () => unawaited(_save()));
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

  /// Writes the dirty fields, and only those, through
  /// [NotesRepository.updateText] -- never the whole row from
  /// `noteByIdProvider`'s copy, which can predate a pin, move or delete
  /// that has already landed and would be written back over it.
  ///
  /// Returns false when the write failed. The flags then stay set, so the
  /// text is neither lost nor overwritten by `_fill`, and the next save --
  /// or [dispose] -- tries again; a snackbar says so meanwhile.
  Future<bool> _save() async {
    _debounce?.cancel();
    if (!mounted) return true;
    final note = ref.read(noteByIdProvider(widget.noteId)).value;
    if (note == null) return true;
    final rawTitle = _title.text.trim();
    // A title cleared to nothing keeps the stored one: it is not written.
    final writeTitle = _titleDirty && rawTitle.isNotEmpty;
    final title = writeTitle ? rawTitle : note.title;
    final body = _bodyDirty ? _body.text : note.body;
    if (title == note.title && body == note.body) {
      // Nothing to write, but a dirty field that trimmed/normalized back
      // to the stored value still needs its flag dropped -- otherwise
      // `_fill` would skip it forever, even though there is no write in
      // flight to wait for.
      _titleDirty = false;
      _bodyDirty = false;
      return true;
    }
    // The flags stay set for the whole write, not cleared up front: `_fill`
    // must keep skipping this field until the note it reads back actually
    // holds what was just written, or it would blow the stale text in the
    // controller onto the old, pre-write note the instant focus is lost
    // (`_onFocusChange`'s `setState` below runs a rebuild before the
    // repository's stream has emitted the new row -- drift runs the write
    // in a background isolate in production, so that gap is real). Cleared
    // only once the field still holds exactly what was written, so a fresh
    // edit made during the `await` isn't mistaken for having landed.
    //
    // Snapshotted as the *raw* field text, before the `await`, and compared
    // against below the same way -- not against `title`/`body`, which are
    // normalized (trimmed, or the stored title when the field was left
    // empty). A trailing space trimmed off, or an empty title that fell
    // back to the stored one, would otherwise never equal what the field
    // still holds, so the flag would stick forever: `_fill` would then keep
    // skipping the field even after its write has landed, letting a later
    // sync arrive, get silently skipped, and then get overwritten by this
    // field's own stale text on the next save (a pop, say).
    final sentTitle = _title.text;
    final sentBody = _body.text;
    final repo = _repo = ref.read(notesRepositoryProvider);
    try {
      await repo.updateText(
        widget.noteId,
        title: writeTitle ? title : null,
        body: _bodyDirty ? body : null,
      );
    } on Object catch (error, stack) {
      // Any failure, not just an Exception: whatever went wrong, the text
      // must stay put and the person must hear that it isn't saved.
      debugPrint('note ${widget.noteId} not saved: $error\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(L.of(context).noteSaveFailed)));
      }
      return false;
    }
    if (!mounted) return true;
    _superseded = note;
    // A field whose flag clears here is settled straight to the value just
    // written -- the trimmed title, or the stored one when it was left
    // blank; the body as typed -- rather than waiting on `_fill`, which
    // would otherwise leave un-normalized text ("Bread ", or a blank
    // title) showing with nothing left to rebuild it. Taken from what was
    // written, never re-read from `noteByIdProvider`: the store's stream
    // lags the write in production (drift's background isolate), so that
    // read would still hold the pre-write note, and filling from it would
    // flash the old text back until the stream caught up -- or, if the
    // field were refocused in between, leave the old text there to be
    // edited and saved over this write. Only while unfocused, like
    // `_fill`; `_onBodyChanged` ignores the change for the same reason.
    if (_title.text == sentTitle) {
      _titleDirty = false;
      if (!_titleFocus.hasFocus && _title.text != title) _title.text = title;
    }
    if (_body.text == sentBody) {
      _bodyDirty = false;
      if (!_bodyFocus.hasFocus && _body.text != body) _body.text = body;
    }
    return true;
  }

  void _apply(TextEditingValue Function(TextEditingValue) command) {
    _body.value = command(_body.value);
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

  void _openTask(String id) => unawaited(context.push(Routes.task(id)));

  Future<void> _makeTodoFromEditor() async {
    final candidates = todoCandidates(_body.value);
    if (candidates.isEmpty) return;
    await _makeTodo(candidates: candidates, anchoredIn: _body.text);
  }

  /// Saves first, so the task is made from what the fields show.
  Future<void> _makeTodoFromNote() async {
    await _save();
    if (!mounted) return;
    await _makeTodo(wholeNote: wholeNoteTodo(_title.text, _body.text));
  }

  /// Asks, creates the tasks, links them in the body and offers undo.
  /// A failure part way deletes what was created and leaves the body as
  /// it was.
  ///
  /// [anchoredIn] is the body the [candidates]' anchors point into. The
  /// sheet stays up as long as the person likes, and a sync can change the
  /// body meanwhile; the anchors would then land links in the wrong place,
  /// so none are added. A whole-note link goes at the end and needs no
  /// anchor.
  Future<void> _makeTodo({
    List<TodoCandidate> candidates = const [],
    WholeNoteTodo? wholeNote,
    String? anchoredIn,
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
    // Read now, while `ref` is usable: Undo sits in a snackbar that
    // outlives this page, and must still work after it has gone.
    final tasks = ref.read(tasksRepositoryProvider);
    final subtasks = ref.read(subtasksRepositoryProvider);
    final notes = ref.read(notesRepositoryProvider);
    final db = ref.read(appDatabaseProvider);
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
      // Each on its own, so one that fails neither stops the rest nor
      // swallows the snackbar.
      for (final id in created) {
        try {
          await tasks.delete(id);
        } on Object catch (error, stack) {
          debugPrint('task $id not rolled back: $error\n$stack');
        }
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.noteTodoFailed)));
      return;
    }
    if (!mounted) return;
    final body = _body.text;
    final link = wholeNote != null || body == anchoredIn;
    if (link) {
      // Through the value, not just the text, so a cursor at an anchor
      // moves past the link that lands there.
      final linked = wholeNote != null
          ? TextEditingValue(
              text: appendTaskLink(body, created.single),
              selection: _body.selection,
            )
          : insertTaskLinksInValue(_body.value, [
              // One draft per candidate, or one task anchored at the first.
              if (created.length == candidates.length)
                for (final (i, id) in created.indexed)
                  (candidates[i].anchor, id)
              else
                (candidates.first.anchor, created.single),
            ]);
      final saved = await _writeBody(linked.text, selection: linked.selection);
      // A failed write has put up its own snackbar: the tasks exist and
      // the links sit in the field, dirty, for the next save to retry --
      // but the note is not saved, and that is what must stay on screen,
      // not a success message over it.
      if (!saved || !mounted) return;
    }
    // A SnackBar has one action: Undo takes it, and Open (one task only)
    // sits in the content.
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Expanded(
                child: Text(
                  link
                      ? l.noteTodoCreated(created.length)
                      : l.noteTodoCreatedNoLink(created.length),
                ),
              ),
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
          // An action makes a snackbar persist by default; this one
          // would then sit over the format bar until dismissed.
          persist: false,
          action: SnackBarAction(
            label: l.commonUndo,
            onPressed: () => unawaited(
              _undoTodo(
                created.toSet(),
                tasks: tasks,
                notes: link ? notes : null,
                db: db,
              ),
            ),
          ),
        ),
      );
  }

  /// Deletes the tasks and, given [notes], takes their links out of the
  /// body: through the editor while the page is up, so the edit is one
  /// the fields know about, or straight onto the stored note once it has
  /// gone. Uses no `ref`, which may be gone by the time Undo is tapped.
  Future<void> _undoTodo(
    Set<String> ids, {
    required TasksRepository tasks,
    required NotesRepository? notes,
    required AppDatabase db,
  }) async {
    // Each on its own, like the rollback: one that fails neither stops the
    // rest nor the links coming out. A task that could not be deleted
    // keeps its link, so the note does not lose track of it.
    final deleted = <String>{};
    for (final id in ids) {
      try {
        await tasks.delete(id);
        deleted.add(id);
      } on Object catch (error, stack) {
        debugPrint('task $id not undone: $error\n$stack');
      }
    }
    if (notes == null || deleted.isEmpty) return;
    if (mounted) {
      final updated = removeTaskLinksInValue(_body.value, deleted);
      await _writeBody(updated.text, selection: updated.selection);
      return;
    }
    final stored = await db.noteById(widget.noteId);
    if (stored == null) return;
    final body = removeTaskLinks(stored.body, deleted);
    if (body != stored.body) {
      await notes.updateText(widget.noteId, body: body);
    }
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
        await _makeTodo(candidates: [candidate!], anchoredIn: body);
      case 'edit':
        _editAt(lineStart);
    }
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
    final readView = _showReadView(note);
    // Cmd on Apple platforms, Ctrl elsewhere -- binding both everywhere
    // would shadow macOS/iOS's native Ctrl+B / Ctrl+K text-field
    // navigation, which the platform's own text field still wants.
    final useMeta =
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.iOS;

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
              icon: Icon(
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
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
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
                          ),
                        ),
                        if (readView)
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
                          )
                        else
                          CallbackShortcuts(
                            bindings: {
                              SingleActivator(
                                LogicalKeyboardKey.keyB,
                                control: !useMeta,
                                meta: useMeta,
                              ): () =>
                                  _apply((v) => toggleInline(v, '**')),
                              SingleActivator(
                                LogicalKeyboardKey.keyI,
                                control: !useMeta,
                                meta: useMeta,
                              ): () =>
                                  _apply((v) => toggleInline(v, '_')),
                              SingleActivator(
                                LogicalKeyboardKey.keyX,
                                control: !useMeta,
                                meta: useMeta,
                                shift: true,
                              ): () =>
                                  _apply((v) => toggleInline(v, '~~')),
                              SingleActivator(
                                LogicalKeyboardKey.keyK,
                                control: !useMeta,
                                meta: useMeta,
                              ): _insertLink,
                              SingleActivator(
                                LogicalKeyboardKey.keyT,
                                control: !useMeta,
                                meta: useMeta,
                                shift: true,
                              ): () =>
                                  unawaited(_makeTodoFromEditor()),
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
                              contextMenuBuilder: (context, state) {
                                final items = [...state.contextMenuButtonItems];
                                if (todoCandidates(state.textEditingValue)
                                    .isNotEmpty) {
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
                        ListTile(
                          key: const Key('note-make-todo'),
                          leading: const Icon(Icons.add_task),
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
