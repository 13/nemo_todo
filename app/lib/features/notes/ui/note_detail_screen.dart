import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/core/widgets/max_width.dart';
import 'package:nemo/features/notes/ui/note_body_view.dart';
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
  final _body = TextEditingController();
  final _titleFocus = FocusNode();
  final _bodyFocus = FocusNode();

  // The body opens rendered -- most visits to a note are to read it, not
  // change it -- and only shows its markdown source once asked to.
  bool _editing = false;

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

  /// Flips read/edit. Leaving edit mode saves first, the same as
  /// unfocusing the field does, since the field is about to disappear
  /// rather than merely lose focus.
  Future<void> _toggleEditing() async {
    if (_editing) await _save();
    setState(() => _editing = !_editing);
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
        appBar: AppBar(
          actions: [
            NotePinAction(note: note),
            IconButton(
              key: const Key('note-edit-toggle'),
              tooltip: _editing ? l.noteReadToggle : l.noteEditToggle,
              icon: Icon(_editing ? Icons.check_rounded : Icons.edit_outlined),
              onPressed: () => unawaited(_toggleEditing()),
            ),
          ],
        ),
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
              if (_editing)
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
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: NoteBodyView(body: note.body),
                ),
              const SizedBox(height: 16),
              PhotoStrip(parentKind: PhotoParent.note, parentId: note.id),
              NoteListPicker(note: note),
              NoteDeleteAction(note: note),
            ],
          ),
        ),
      ),
    );
  }
}
