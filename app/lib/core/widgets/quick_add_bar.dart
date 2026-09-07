import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/core/theme/nemo_colors.dart';
import 'package:nemo/core/widgets/list_icons.dart';
import 'package:nemo/features/lists/ui/lists_providers.dart';
import 'package:nemo/features/tasks/ui/tasks_providers.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/utils/dates.dart';
import 'package:nemo/utils/format.dart';

/// Bottom bar that turns a typed title into a task in one step.
///
/// The chips set date, priority and (when [showListPicker]) the list; the
/// field keeps focus after submitting so several tasks can be entered.
class QuickAddBar extends ConsumerStatefulWidget {
  const QuickAddBar({
    required this.listId,
    this.defaultDueAt,
    this.showListPicker = false,
    super.key,
  });

  /// Preselected list; the Inbox is used when null.
  final String? listId;
  final int? defaultDueAt;
  final bool showListPicker;

  @override
  ConsumerState<QuickAddBar> createState() => _QuickAddBarState();
}

class _QuickAddBarState extends ConsumerState<QuickAddBar> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  int? _dueAt;
  int _priority = 0;
  String? _listId;

  @override
  void initState() {
    super.initState();
    _dueAt = widget.defaultDueAt;
    _listId = widget.listId;
  }

  @override
  void didUpdateWidget(QuickAddBar old) {
    super.didUpdateWidget(old);
    if (old.listId != widget.listId) _listId = widget.listId;
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    final lists = ref.read(allListsProvider).value ?? const [];
    final listId =
        _listId ??
        lists.where((l) => l.isInbox).firstOrNull?.id ??
        lists.firstOrNull?.id;
    if (listId == null) return;
    await ref
        .read(tasksRepositoryProvider)
        .create(
          listId: listId,
          title: title,
          dueAt: _dueAt,
          priority: _priority,
        );
    if (!mounted) return;
    _controller.clear();
    setState(() {
      _dueAt = widget.defaultDueAt;
      _priority = 0;
    });
    _focus.requestFocus();
  }

  Future<void> _pickDate() async {
    final now = ref.read(nowProvider)();
    final initial = _dueAt == null
        ? now
        : DateTime.fromMillisecondsSinceEpoch(_dueAt!);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() => _dueAt = dayStartMs(picked));
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final scheme = Theme.of(context).colorScheme;
    final nemo = context.nemoColors;
    final now = ref.watch(nowProvider)();
    final locale = Localizations.localeOf(context).toString();
    final lists = ref.watch(allListsProvider).value ?? const [];
    final list = lists.where((x) => x.id == _listId).firstOrNull;

    return Material(
      color: scheme.surface,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('quick-add-field'),
                      controller: _controller,
                      focusNode: _focus,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        hintText: l.tasksAddHint,
                        prefixIcon: const Icon(Icons.add_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    key: const Key('quick-add-submit'),
                    tooltip: l.commonAdd,
                    onPressed: _submit,
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ActionChip(
                      key: const Key('quick-add-date'),
                      avatar: const Icon(Icons.schedule_rounded, size: 18),
                      label: Text(
                        _dueAt == null
                            ? l.tasksNoDue
                            : dueLabel(
                                l,
                                locale,
                                dueAt: _dueAt!,
                                hasTime: false,
                                now: now,
                              ),
                      ),
                      onPressed: _pickDate,
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<int>(
                      tooltip: l.tasksPriority,
                      onSelected: (p) => setState(() => _priority = p),
                      itemBuilder: (_) => [
                        for (final (value, label) in [
                          (0, l.priorityNone),
                          (1, l.priorityLow),
                          (2, l.priorityMedium),
                          (3, l.priorityHigh),
                        ])
                          PopupMenuItem(
                            value: value,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.flag_rounded,
                                  size: 18,
                                  color: nemo.priority(value) ?? scheme.outline,
                                ),
                                const SizedBox(width: 8),
                                Text(label),
                              ],
                            ),
                          ),
                      ],
                      child: Chip(
                        key: const Key('quick-add-priority'),
                        avatar: Icon(
                          Icons.flag_rounded,
                          size: 18,
                          color: nemo.priority(_priority) ?? scheme.outline,
                        ),
                        label: Text(switch (_priority) {
                          1 => l.priorityLow,
                          2 => l.priorityMedium,
                          3 => l.priorityHigh,
                          _ => l.tasksPriority,
                        }),
                      ),
                    ),
                    if (widget.showListPicker) ...[
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        tooltip: l.tasksList,
                        onSelected: (id) => setState(() => _listId = id),
                        itemBuilder: (_) => [
                          for (final x in lists)
                            PopupMenuItem(
                              value: x.id,
                              child: Row(
                                children: [
                                  Icon(
                                    listIcon(x.icon),
                                    size: 18,
                                    color: nemo.listColor(x.color),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(x.isInbox ? l.listsInbox : x.name),
                                ],
                              ),
                            ),
                        ],
                        child: Chip(
                          key: const Key('quick-add-list'),
                          avatar: Icon(
                            listIcon(list?.icon ?? 'inbox'),
                            size: 18,
                            color: list == null
                                ? scheme.outline
                                : nemo.listColor(list.color),
                          ),
                          label: Text(
                            list == null || list.isInbox
                                ? l.listsInbox
                                : list.name,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
