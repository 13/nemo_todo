import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/features/notes/ui/markdown/note_format_toolbar.dart'
    show isWebLink;
import 'package:nemo/features/notes/ui/markdown/note_to_task.dart';
import 'package:nemo/features/settings/ui/about_tile.dart' show openUrlProvider;
import 'package:nemo/features/tasks/ui/tasks_providers.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/router.dart';

/// Opens a link tapped in a note: a task link in the app, a web link in
/// the browser, anything else not at all.
void openNoteLink(BuildContext context, WidgetRef ref, String url) {
  final taskId = taskIdFromLink(url);
  if (taskId != null) {
    unawaited(context.push(Routes.task(taskId)));
  } else if (isWebLink(url)) {
    unawaited(ref.read(openUrlProvider)(Uri.parse(url)));
  }
}

/// A task a note links to, drawn live in the read view: its title, and
/// whether it is open, done or gone. Tapping opens it.
class TaskLinkChip extends ConsumerWidget {
  const TaskLinkChip({required this.taskId, super.key});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final colors = Theme.of(context).colorScheme;
    final watched = ref.watch(taskByIdProvider(taskId));
    final task = watched.value;
    // Deleted only once the store has said so: until the first answer
    // the chip shows as an open task, not a flash of "Task deleted".
    final gone = watched.hasValue && (task == null || task.isDeleted);
    final (IconData icon, Color color, String label) = gone
        ? (Icons.remove_circle_outline, colors.outline, l.noteTaskDeleted)
        : task == null
        ? (Icons.task_alt, colors.primary, '')
        : task.done
        ? (Icons.check_circle, colors.primary, task.title)
        : (Icons.task_alt, colors.primary, task.title);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: ActionChip(
        key: Key('task-link-chip-$taskId'),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        avatar: Icon(icon, size: 16, color: color),
        label: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        onPressed: () => unawaited(context.push(Routes.task(taskId))),
      ),
    );
  }
}
