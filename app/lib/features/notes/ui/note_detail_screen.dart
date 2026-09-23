import 'dart:async';

import 'package:flutter/foundation.dart';
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

  // Whether a field holds an edit the store hasn't seen yet. `_save` only
  // writes a dirty field; a clean one takes the stored note's value
  // instead. Without this, focusing a field (with no typing) while a sync
  // changes it, then unfocusing, would save the field's stale text over
  // the sync -- `_fill` correctly skips a focused field, but the old text
  // it left behind is otherwise indistinguishable from a real edit.
  bool _titleDirty = false;
  bool _bodyDirty = false;

  @override
  void initState() {
    super.initState();
    _titleFocus.addListener(_onFocusChange);
    _bodyFocus.addListener(_onFocusChange);
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
    if (_bodyFocus.hasFocus) {
      _bodyDirty = true;
      _scheduleSave();
    }
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
  /// otherwise move the cursor out from under whoever is typing. A dirty
  /// field is skipped too -- it holds an edit `_save` hasn't reconciled
  /// yet, on the sliver of time between losing focus and that finishing.
  void _fill(Note note) {
    if (!_titleFocus.hasFocus && !_titleDirty && _title.text != note.title) {
      _title.text = note.title;
    }
    if (!_bodyFocus.hasFocus && !_bodyDirty && _body.text != note.body) {
      _body.text = note.body;
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
    if (_titleFocus.hasFocus || _bodyFocus.hasFocus) return;
    unawaited(_save());
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    _debounce?.cancel();
    final note = ref.read(noteByIdProvider(widget.noteId)).value;
    if (note == null) return;
    final rawTitle = _title.text.trim();
    final title = _titleDirty && rawTitle.isNotEmpty ? rawTitle : note.title;
    final body = _bodyDirty ? _body.text : note.body;
    // Cleared up front, synchronously: whatever the fields hold has now
    // been folded into `title`/`body`, dirty or not, so nothing typed
    // after this point should be lost to the flag still reading true.
    _titleDirty = false;
    _bodyDirty = false;
    if (title == note.title && body == note.body) return;
    await ref
        .read(notesRepositoryProvider)
        .save(note.copyWith(title: title, body: body));
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
                        ): () => unawaited(
                          promptForLink(context, _body, focusNode: _bodyFocus),
                        ),
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
                    PhotoStrip(parentKind: PhotoParent.note, parentId: note.id),
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
                      focusNode: _bodyFocus,
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
