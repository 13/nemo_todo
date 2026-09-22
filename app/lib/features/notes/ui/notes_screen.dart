import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/core/widgets/empty_state.dart';
import 'package:nemo/core/widgets/max_width.dart';
import 'package:nemo/features/lists/ui/lists_providers.dart';
import 'package:nemo/features/notes/ui/notes_providers.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/router.dart';
import 'package:nemo_core/nemo_core.dart';

/// Every note there is, under the list it belongs to.
class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final notes = ref.watch(allNotesProvider).value ?? const <Note>[];
    final lists = ref.watch(allListsProvider).value ?? const <TaskList>[];
    final byList = <String, List<Note>>{};
    for (final note in notes) {
      (byList[note.listId] ??= []).add(note);
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.navNotes)),
      floatingActionButton: lists.isEmpty
          ? null
          : FloatingActionButton(
              key: const Key('note-create'),
              onPressed: () async {
                final note = await ref
                    .read(notesRepositoryProvider)
                    .create(listId: lists.first.id, title: l.noteNewTitle);
                if (context.mounted) {
                  unawaited(context.push(Routes.note(note.id)));
                }
              },
              child: const Icon(Icons.add),
            ),
      body: notes.isEmpty
          ? EmptyState(
              icon: Icons.sticky_note_2_outlined,
              message: l.notesEmpty,
            )
          : MaxWidth(
              child: ListView(
                children: [
                  for (final list in lists)
                    if (byList[list.id] case final held?) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                        child: Text(
                          list.name,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      for (final note in held) _NoteTile(note: note),
                    ],
                ],
              ),
            ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final preview = note.body.trim();
    return ListTile(
      key: Key('note-tile-${note.id}'),
      title: Text(note.title),
      // The preview is the markdown source, not rendered: a heading or an
      // image in a long note would otherwise set the height of a row in a
      // list of dozens.
      subtitle: Text(
        preview.isEmpty ? l.notePreviewEmpty : preview,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: note.pinned ? const Icon(Icons.push_pin, size: 18) : null,
      onTap: () => context.push(Routes.note(note.id)),
    );
  }
}
