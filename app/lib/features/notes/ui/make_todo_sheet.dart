/// The sheet that turns note text into one or more tasks.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/core/widgets/max_width.dart';
import 'package:nemo/features/lists/ui/lists_providers.dart';
import 'package:nemo/features/notes/ui/markdown/note_to_task.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/utils/dates.dart';
import 'package:nemo/utils/format.dart';
import 'package:nemo_core/nemo_core.dart';

typedef WholeNoteTodo = ({
  String title,
  String notes,
  String notesWithoutChecklist,
  List<String> checklist,
});

/// One task the sheet asks for.
class TodoDraft {
  const TodoDraft({
    required this.title,
    this.subtasks = const [],
    this.notes = '',
  });

  final String title;
  final List<String> subtasks;
  final String notes;
}

/// What the person confirmed. Per-line mode has one draft per candidate,
/// in candidate order; every other mode has exactly one.
class MakeTodoResult {
  const MakeTodoResult({
    required this.tasks,
    required this.listId,
    this.dueAt,
    this.priority = 0,
  });

  final List<TodoDraft> tasks;
  final String listId;
  final int? dueAt;
  final int priority;
}

/// Asks how [candidates], or the [wholeNote], should become tasks. Null
/// when dismissed. Writes nothing: the caller creates the tasks.
Future<MakeTodoResult?> showMakeTodoSheet(
  BuildContext context, {
  required String listId,
  List<TodoCandidate> candidates = const [],
  WholeNoteTodo? wholeNote,
}) => showModalBottomSheet<MakeTodoResult>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _MakeTodoSheet(
    candidates: candidates,
    wholeNote: wholeNote,
    listId: listId,
  ),
);

enum _Shape { perLine, withSubtasks }

class _MakeTodoSheet extends ConsumerStatefulWidget {
  const _MakeTodoSheet({
    required this.candidates,
    required this.wholeNote,
    required this.listId,
  });

  final List<TodoCandidate> candidates;
  final WholeNoteTodo? wholeNote;
  final String listId;

  @override
  ConsumerState<_MakeTodoSheet> createState() => _MakeTodoSheetState();
}

class _MakeTodoSheetState extends ConsumerState<_MakeTodoSheet> {
  late final _title = TextEditingController(
    text: widget.wholeNote?.title ?? widget.candidates.firstOrNull?.title ?? '',
  );
  _Shape _shape = _Shape.perLine;
  var _checklistAsSubtasks = true;
  String? _listId;
  int? _dueAt;
  var _priority = 0;

  bool get _several => widget.wholeNote == null && widget.candidates.length > 1;
  bool get _titled => !_several || _shape == _Shape.withSubtasks;

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final now = ref.read(nowProvider)();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueAt == null
          ? now
          : DateTime.fromMillisecondsSinceEpoch(_dueAt!),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _dueAt = dayStartMs(picked));
  }

  List<TodoDraft> _drafts() {
    final whole = widget.wholeNote;
    if (whole != null) {
      final sub = _checklistAsSubtasks && whole.checklist.isNotEmpty;
      return [
        TodoDraft(
          title: _title.text.trim(),
          subtasks: sub ? whole.checklist : const [],
          notes: sub ? whole.notesWithoutChecklist : whole.notes,
        ),
      ];
    }
    if (!_several) return [TodoDraft(title: _title.text.trim())];
    if (_shape == _Shape.withSubtasks) {
      return [
        TodoDraft(
          title: _title.text.trim(),
          subtasks: [for (final c in widget.candidates.skip(1)) c.title],
        ),
      ];
    }
    return [for (final c in widget.candidates) TodoDraft(title: c.title)];
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).toString();
    final lists = ref.watch(allListsProvider).value ?? const <TaskList>[];
    // The note's list, or Inbox when that list is gone.
    final listId =
        _listId ??
        (lists.any((x) => x.id == widget.listId)
            ? widget.listId
            : lists.where((x) => x.isInbox).firstOrNull?.id ??
                  lists.firstOrNull?.id);
    final canCreate =
        listId != null && (!_titled || _title.text.trim().isNotEmpty);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: MaxWidth(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_several) ...[
                SegmentedButton<_Shape>(
                  segments: [
                    ButtonSegment(
                      value: _Shape.perLine,
                      label: Text(
                        l.noteTodoPerLine,
                        key: const Key('todo-shape-lines'),
                      ),
                    ),
                    ButtonSegment(
                      value: _Shape.withSubtasks,
                      label: Text(
                        l.noteTodoWithSubtasks,
                        key: const Key('todo-shape-subtasks'),
                      ),
                    ),
                  ],
                  selected: {_shape},
                  onSelectionChanged: (s) => setState(() => _shape = s.single),
                ),
                const SizedBox(height: 12),
              ],
              if (_titled)
                TextField(
                  key: const Key('todo-title'),
                  controller: _title,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(labelText: l.tasksTitleHint),
                ),
              if (_several && _shape == _Shape.perLine)
                for (final (i, c) in widget.candidates.indexed)
                  ListTile(
                    key: Key('todo-line-$i'),
                    dense: true,
                    leading: const Icon(Icons.task_alt, size: 18),
                    title: Text(c.title),
                  ),
              if (_several && _shape == _Shape.withSubtasks)
                for (final c in widget.candidates.skip(1))
                  ListTile(
                    dense: true,
                    leading: const Icon(
                      Icons.subdirectory_arrow_right,
                      size: 18,
                    ),
                    title: Text(c.title),
                  ),
              if (widget.wholeNote?.checklist.isNotEmpty ?? false)
                SwitchListTile(
                  key: const Key('todo-checklist-subtasks'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.noteTodoChecklistSubtasks),
                  value: _checklistAsSubtasks,
                  onChanged: (v) => setState(() => _checklistAsSubtasks = v),
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const Key('todo-list'),
                initialValue: listId,
                decoration: InputDecoration(labelText: l.tasksList),
                items: [
                  for (final list in lists)
                    DropdownMenuItem(value: list.id, child: Text(list.name)),
                ],
                onChanged: (v) => setState(() => _listId = v),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  InputChip(
                    key: const Key('todo-due'),
                    avatar: const Icon(Icons.event_outlined, size: 18),
                    label: Text(
                      _dueAt == null
                          ? l.tasksNoDue
                          : dateLabel(locale, _dueAt!),
                    ),
                    onPressed: () => unawaited(_pickDue()),
                    onDeleted: _dueAt == null
                        ? null
                        : () => setState(() => _dueAt = null),
                  ),
                  for (final (value, label) in [
                    (0, l.priorityNone),
                    (1, l.priorityLow),
                    (2, l.priorityMedium),
                    (3, l.priorityHigh),
                  ])
                    ChoiceChip(
                      key: Key('todo-priority-$value'),
                      label: Text(label),
                      selected: _priority == value,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _priority = value),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                key: const Key('todo-create'),
                onPressed: canCreate
                    ? () => Navigator.pop(
                        context,
                        MakeTodoResult(
                          tasks: _drafts(),
                          listId: listId,
                          dueAt: _dueAt,
                          priority: _priority,
                        ),
                      )
                    : null,
                child: Text(l.noteTodoCreate),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
