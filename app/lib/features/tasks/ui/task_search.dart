import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/core/widgets/account_action.dart';
import 'package:nemo/core/widgets/app_icon.dart';
import 'package:nemo/core/widgets/settings_action.dart';
import 'package:nemo/features/notes/ui/notes_providers.dart';
import 'package:nemo/features/tasks/ui/selected_task.dart';
import 'package:nemo/features/tasks/ui/tasks_providers.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/router.dart';
import 'package:nemo/screens/shell_screen.dart';

/// Search as Android's own apps offer it: a rounded bar at the top of the
/// home screen with the account beside it ([TaskSearch.bar]), or a search
/// button in a screen's toolbar ([TaskSearch.button]); either opens
/// Material's search view over the screen, with tasks and notes as you
/// type.
class TaskSearch extends ConsumerStatefulWidget {
  const TaskSearch.bar({super.key}) : _bar = true;

  const TaskSearch.button({super.key}) : _bar = false;

  final bool _bar;

  @override
  ConsumerState<TaskSearch> createState() => _TaskSearchState();
}

class _TaskSearchState extends ConsumerState<TaskSearch> {
  final _controller = SearchController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final scheme = Theme.of(context).colorScheme;
    const actions = [AccountAction(), SettingsAction()];
    final anchor = SearchAnchor(
      searchController: _controller,
      viewHintText: l.searchHint,
      builder: (context, controller) => widget._bar
          ? SearchBar(
              key: const Key('search-bar'),
              controller: controller,
              hintText: l.searchHint,
              elevation: const WidgetStatePropertyAll(0),
              backgroundColor: WidgetStatePropertyAll(
                scheme.surfaceContainerHigh,
              ),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.only(left: 16, right: 4),
              ),
              leading: const AppIcon(Icons.search_rounded),
              // Room for the account and Settings, two icon buttons laid
              // over the bar below rather than inside it; a wide window
              // shows neither, as the rail has them.
              trailing: [
                if (MediaQuery.sizeOf(context).width <
                    ShellScreen.railBreakpoint)
                  const SizedBox(width: 2 * kMinInteractiveDimension),
              ],
              onTap: controller.openView,
              onChanged: (_) => controller.openView(),
            )
          : IconButton(
              key: const Key('search-button'),
              tooltip: l.navSearch,
              icon: const AppIcon(Icons.search_rounded),
              onPressed: controller.openView,
            ),
      // One live list rather than a query per keystroke: it watches the
      // same results the Search page does, and follows them as they change.
      suggestionsBuilder: (context, controller) => [
        _Results(query: controller.text.trim(), controller: controller),
      ],
    );
    // The anchor listens for the tap around the button as well as the
    // button itself; one node, named by the button's tooltip, not two.
    if (!widget._bar) return MergeSemantics(child: anchor);
    // Flutter's bar is three unnamed nodes to a screen reader -- the
    // anchor, the bar and a field one line high -- that all open the
    // search. It is one button, named by its hint, with the account and
    // Settings beside it as buttons of their own.
    return Stack(
      alignment: AlignmentDirectional.centerEnd,
      children: [
        Semantics(
          button: true,
          label: l.searchHint,
          onTap: _controller.openView,
          excludeSemantics: true,
          child: anchor,
        ),
        const Padding(
          padding: EdgeInsetsDirectional.only(end: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: actions),
        ),
      ],
    );
  }
}

/// What matches [query]: tasks, then notes; tapping one closes the search
/// and opens it.
class _Results extends ConsumerWidget {
  const _Results({required this.query, required this.controller});

  final String query;
  final SearchController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (query.isEmpty) return const SizedBox.shrink();
    final l = L.of(context);
    final tasks = ref.watch(searchTasksProvider(query)).value ?? const [];
    final notes = ref.watch(noteSearchProvider(query)).value ?? const [];
    if (tasks.isEmpty && notes.isEmpty) {
      return ListTile(title: Text(l.searchNoResults(query)));
    }
    return Column(
      children: [
        for (final task in tasks)
          ListTile(
            key: Key('search-task-${task.id}'),
            leading: AppIcon(
              task.done
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked,
            ),
            title: Text(task.title),
            onTap: () {
              controller.closeView(null);
              openTask(context, ref, task.id);
            },
          ),
        for (final note in notes)
          ListTile(
            key: Key('search-note-${note.id}'),
            leading: const AppIcon(Icons.sticky_note_2_outlined),
            title: Text(note.title),
            onTap: () {
              controller.closeView(null);
              unawaited(context.push(Routes.note(note.id)));
            },
          ),
      ],
    );
  }
}
