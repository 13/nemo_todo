part of 'note_detail_screen.dart';

/// Making tasks from a note: from the selection or a line in the editor,
/// from a line in the read view, or from the whole note -- each linked
/// back from the body, with an undo that takes both away again.
mixin _NoteTodos on ConsumerState<NoteDetailScreen>, _NoteSaving {
  Future<bool> _writeBody(String body, {TextSelection? selection});
  void _openTask(String id);
  void _editAt(int offset);

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
}
