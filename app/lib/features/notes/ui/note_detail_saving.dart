part of 'note_detail_screen.dart';

/// Keeps the note page's fields and the stored note in step: saves an
/// edit after a pause in typing or on leaving the field, and takes in a
/// sync without trampling what is being typed.
mixin _NoteSaving on ConsumerState<NoteDetailScreen> {
  TextEditingController get _title;
  MarkdownEditingController get _body;
  FocusNode get _titleFocus;
  FocusNode get _bodyFocus;

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

  /// Called from `dispose`: writes whatever is still dirty, since the page
  /// is going without a save of its own.
  void _flushOnDispose() {
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
}
