import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/features/lists/ui/lists_providers.dart';
import 'package:nemo/features/notes/ui/notes_providers.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/router.dart';
import 'package:nemo_core/nemo_core.dart';

/// Pins a note to the top of its list, or unpins it.
class NotePinAction extends ConsumerWidget {
  const NotePinAction({required this.note, super.key});

  final Note note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    return IconButton(
      key: const Key('note-pin'),
      tooltip: note.pinned ? l.noteUnpin : l.notePin,
      icon: Icon(note.pinned ? Icons.push_pin : Icons.push_pin_outlined),
      onPressed: () => ref
          .read(notesRepositoryProvider)
          .setPinned(note.id, pinned: !note.pinned),
    );
  }
}

/// Moves a note to another list. Its pictures go with it, because they
/// name the note, not the list.
class NoteListPicker extends ConsumerWidget {
  const NoteListPicker({required this.note, super.key});

  final Note note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    // Watched, not read-on-tap: `allListsProvider` streams from drift, and
    // reading it cold inside `onTap` can still be `AsyncLoading` if nothing
    // on this page subscribed to it earlier (a note reached directly, not
    // via the notes list, never has). Watching in build warms it up as
    // soon as the note itself is loaded, well before anyone can tap here.
    final lists = ref.watch(allListsProvider).value ?? const <TaskList>[];
    return ListTile(
      key: const Key('note-move'),
      leading: const Icon(Icons.folder_outlined),
      title: Text(l.noteMoveToList),
      onTap: () async {
        final chosen = await showModalBottomSheet<String>(
          context: context,
          builder: (context) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final list in lists)
                  ListTile(
                    title: Text(list.name),
                    selected: list.id == note.listId,
                    onTap: () => Navigator.of(context).pop(list.id),
                  ),
              ],
            ),
          ),
        );
        if (chosen == null || chosen == note.listId) return;
        await ref.read(notesRepositoryProvider).moveToList(note.id, chosen);
      },
    );
  }
}

/// Asks, deletes, and offers undo -- the same tier of confirmation a task
/// or a list gets, since a note is a top-level entity like them, not a
/// throwaway subitem.
class NoteDeleteAction extends ConsumerWidget {
  const NoteDeleteAction({required this.note, super.key});

  final Note note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    return ListTile(
      key: const Key('note-delete'),
      leading: const Icon(Icons.delete_outline),
      title: Text(l.noteDelete),
      onTap: () => _delete(context, ref),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l = L.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.commonDelete),
        content: Text(l.notesDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            key: const Key('confirm-delete-note'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.commonDelete),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final repo = ref.read(notesRepositoryProvider);
    await repo.delete(note.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l.notesDeleted),
        // An action would keep it up until tapped.
        persist: false,
        action: SnackBarAction(
          label: l.commonUndo,
          onPressed: () => repo.restore(note.id),
        ),
      ),
    );
    // A note reached directly -- a deep link, a shared URL, a PWA restore
    // -- can be the only page on the stack, with nothing below it to pop
    // back to.
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.notes);
    }
  }
}
