import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/core/widgets/account_action.dart';
import 'package:nemo/core/widgets/async_body.dart';
import 'package:nemo/core/widgets/empty_state.dart';
import 'package:nemo/core/widgets/section_header.dart';
import 'package:nemo/core/widgets/settings_action.dart';
import 'package:nemo/features/notes/ui/notes_providers.dart';
import 'package:nemo/features/tasks/ui/task_list_view.dart';
import 'package:nemo/features/tasks/ui/tasks_providers.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/router.dart';
import 'package:nemo_core/nemo_core.dart';

/// Full-text search over titles, notes and tags of every list, and over
/// note titles and bodies.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  var _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final results = ref.watch(searchTasksProvider(_query));
    // Resolves fast against the same local database; while it is still
    // loading the section is simply absent, the way NotesScreen already
    // treats `allNotesProvider` before its first emission.
    final notes = ref.watch(noteSearchProvider(_query)).value ?? const <Note>[];
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          key: const Key('search-field'),
          controller: _controller,
          autofocus: true,
          onChanged: (value) => setState(() => _query = value.trim()),
          decoration: InputDecoration(
            hintText: l.searchHint,
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      _controller.clear();
                      setState(() => _query = '');
                    },
                  ),
          ),
        ),
        actions: const [AccountAction(), SettingsAction()],
      ),
      body: _query.isEmpty
          ? EmptyState(icon: Icons.search_rounded, message: l.searchEmpty)
          : AsyncBody(
              value: results,
              data: (items) => items.isEmpty && notes.isEmpty
                  ? EmptyState(
                      icon: Icons.search_off_rounded,
                      message: l.searchNoResults(_query),
                    )
                  // Tasks and then notes, one after another in a single
                  // scroll, each headed section hidden when its own side of
                  // the search turned up nothing.
                  : CustomScrollView(
                      slivers: [
                        if (items.isNotEmpty)
                          TaskListSlivers(
                            showList: true,
                            sections: [
                              TaskSection(
                                title: l.searchTasksHeader,
                                tasks: items.where((t) => !t.done).toList(),
                              ),
                            ],
                            completed: items.where((t) => t.done).toList(),
                          ),
                        if (notes.isNotEmpty) ..._noteResultSlivers(notes, l),
                      ],
                    ),
            ),
    );
  }
}

/// The note half of a search result: a header sliver and the matching
/// notes, tapping one of them opening it the way `/notes` does.
List<Widget> _noteResultSlivers(List<Note> notes, L l) => [
  SliverToBoxAdapter(
    child: SectionHeader(
      key: const Key('search-notes-header'),
      title: l.searchNotesHeader,
      count: notes.length,
    ),
  ),
  SliverList.builder(
    itemCount: notes.length,
    itemBuilder: (context, i) => _NoteResultTile(note: notes[i]),
  ),
];

/// Mirrors the tile `NotesScreen` uses, so a note reads the same way
/// wherever it is listed.
class _NoteResultTile extends StatelessWidget {
  const _NoteResultTile({required this.note});

  final Note note;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final preview = note.body.trim();
    return ListTile(
      key: Key('search-note-tile-${note.id}'),
      title: Text(note.title),
      // The preview is the markdown source, not rendered: a heading or an
      // image in a note would otherwise set the height of a row in a list
      // of results.
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
