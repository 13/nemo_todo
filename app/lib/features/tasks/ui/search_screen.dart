import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/widgets/account_action.dart';
import 'package:nemo/core/widgets/async_body.dart';
import 'package:nemo/core/widgets/empty_state.dart';
import 'package:nemo/core/widgets/settings_action.dart';
import 'package:nemo/features/tasks/ui/task_list_view.dart';
import 'package:nemo/features/tasks/ui/tasks_providers.dart';
import 'package:nemo/l10n/app_localizations.dart';

/// Full-text search over titles, notes and tags of every list.
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
              data: (items) => items.isEmpty
                  ? EmptyState(
                      icon: Icons.search_off_rounded,
                      message: l.searchNoResults(_query),
                    )
                  : TaskListView(
                      showList: true,
                      sections: [
                        TaskSection(
                          title: l.tasksOpen,
                          tasks: items.where((t) => !t.done).toList(),
                        ),
                      ],
                      completed: items.where((t) => t.done).toList(),
                    ),
            ),
    );
  }
}
