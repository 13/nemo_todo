import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/widgets/max_width.dart';
import 'package:nemo/features/notes/ui/notes_providers.dart';
import 'package:nemo/l10n/app_localizations.dart';
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
  final _body = TextEditingController();
  final _titleFocus = FocusNode();
  final _bodyFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _titleFocus.addListener(_saveIfUnfocused);
    _bodyFocus.addListener(_saveIfUnfocused);
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
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

  void _saveIfUnfocused() {
    if (_titleFocus.hasFocus || _bodyFocus.hasFocus) return;
    unawaited(_save());
  }

  Future<void> _save() async {
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

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final note = ref.watch(noteByIdProvider(widget.noteId)).value;
    if (note == null) {
      // Either the stream has not delivered its first value yet, or the
      // note was deleted out from under this page; either way there is
      // nothing to edit, and no dedicated copy was asked for either state.
      return const Scaffold(body: SizedBox.shrink());
    }
    _fill(note);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _save();
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(),
        body: MaxWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              TextField(
                key: const Key('note-title'),
                controller: _title,
                focusNode: _titleFocus,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  hintText: l.noteTitleHint,
                  filled: false,
                  border: InputBorder.none,
                ),
              ),
              // Task 6 replaces this with NoteBodyView's rendered markdown
              // once the note is not the one being edited; for now the body
              // is always the plain source.
              TextField(
                key: const Key('note-body'),
                controller: _body,
                focusNode: _bodyFocus,
                maxLines: null,
                minLines: 6,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: l.noteBodyHint,
                  filled: false,
                  border: InputBorder.none,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
