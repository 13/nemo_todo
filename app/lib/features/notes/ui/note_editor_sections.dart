import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/features/lists/ui/lists_providers.dart';
import 'package:nemo/features/notes/ui/notes_providers.dart';
import 'package:nemo/l10n/app_localizations.dart';
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
      tooltip: note.pinned ? l.noteUnpin : l.notePinned,
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

/// Tombstones a note and leaves the page.
class NoteDeleteAction extends ConsumerWidget {
  const NoteDeleteAction({required this.note, super.key});

  final Note note;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    return ListTile(
      key: const Key('note-delete'),
      leading: const Icon(Icons.delete_outline),
      title: Text(l.noteDeleted),
      onTap: () async {
        await ref.read(notesRepositoryProvider).delete(note.id);
        if (context.mounted) Navigator.of(context).maybePop();
      },
    );
  }
}
