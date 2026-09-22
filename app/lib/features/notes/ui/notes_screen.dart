import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/core/widgets/empty_state.dart';
import 'package:nemo/core/widgets/max_width.dart';
import 'package:nemo/features/lists/ui/lists_providers.dart';
import 'package:nemo/features/notes/ui/note_card.dart';
import 'package:nemo/features/notes/ui/notes_providers.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/router.dart';
import 'package:nemo_core/nemo_core.dart';

/// Every note there is, as a grid of cards the way Google Keep shows them:
/// pinned notes first, under their own heading, then the rest.
class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    // Newest first. A note's sortKey only orders it within its own list,
    // and this grid mixes every list.
    final notes = [...?ref.watch(allNotesProvider).value]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final lists = ref.watch(allListsProvider).value ?? const <TaskList>[];
    final listNames = {for (final list in lists) list.id: list.name};
    final pinned = [
      for (final note in notes)
        if (note.pinned) note,
    ];
    final others = [
      for (final note in notes)
        if (!note.pinned) note,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l.navNotes)),
      floatingActionButton: lists.isEmpty
          ? null
          : FloatingActionButton(
              key: const Key('note-create'),
              onPressed: () async {
                // Inbox by default, the way QuickAddBar picks a list for a
                // new task when none is preselected.
                final listId =
                    lists.where((x) => x.isInbox).firstOrNull?.id ??
                    lists.first.id;
                final note = await ref
                    .read(notesRepositoryProvider)
                    .create(listId: listId, title: l.noteNewTitle);
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
          // Wider than the app's usual 720: a grid of cards uses the room
          // a column of text rows could not.
          : MaxWidth(
              maxWidth: 1200,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final columns = switch (constraints.maxWidth) {
                    >= 900 => 4,
                    >= 600 => 3,
                    _ => 2,
                  };
                  Widget grid(List<Note> held) => SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    sliver: SliverMasonryGrid.count(
                      crossAxisCount: columns,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childCount: held.length,
                      itemBuilder: (context, i) => NoteCard(
                        note: held[i],
                        listName: listNames[held[i].listId],
                      ),
                    ),
                  );
                  Widget label(String text, Key key) => SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        text,
                        key: key,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                  );
                  return CustomScrollView(
                    slivers: [
                      // Keep's rule: the headings appear only once there is
                      // a pinned note to set apart from the rest.
                      if (pinned.isNotEmpty) ...[
                        label(l.notesPinned, const Key('notes-pinned-label')),
                        grid(pinned),
                        if (others.isNotEmpty)
                          label(l.notesOthers, const Key('notes-others-label')),
                      ] else
                        const SliverToBoxAdapter(child: SizedBox(height: 8)),
                      if (others.isNotEmpty) grid(others),
                      // Room to scroll the last cards out from under the FAB.
                      const SliverToBoxAdapter(child: SizedBox(height: 88)),
                    ],
                  );
                },
              ),
            ),
    );
  }
}
