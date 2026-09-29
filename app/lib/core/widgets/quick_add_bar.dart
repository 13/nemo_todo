import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/core/theme/app_style.dart';
import 'package:nemo/core/theme/nemo_colors.dart';
import 'package:nemo/core/widgets/app_icon.dart';
import 'package:nemo/core/widgets/list_icons.dart';
import 'package:nemo/core/widgets/presentation.dart';
import 'package:nemo/features/lists/ui/lists_providers.dart';
import 'package:nemo/features/tasks/ui/selected_task.dart';
import 'package:nemo/features/tasks/ui/tasks_providers.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/screens/style_adaptation.dart';
import 'package:nemo/utils/dates.dart';
import 'package:nemo/utils/format.dart';
import 'package:nemo/utils/quick_add_parser.dart';

/// Bottom bar that turns a typed title into a task in one step.
///
/// The chips set date, priority and (when [showListPicker]) the list; the
/// field keeps focus after submitting so several tasks can be entered.
class QuickAddBar extends ConsumerStatefulWidget {
  const QuickAddBar({
    required this.listId,
    this.defaultDueAt,
    this.showListPicker = false,
    this.inSheet = false,
    this.onAdded,
    super.key,
  });

  /// Drawn inside a sheet (the Material style's way to add): flat, with
  /// the keyboard up from the start.
  final bool inSheet;

  /// Called after a task is added, in place of staying ready for the next;
  /// a sheet closes itself here.
  final VoidCallback? onAdded;

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

  /// The keyboard's N, from wherever it was pressed.
  late final ValueNotifier<int> _focusRequests = ref.read(
    quickAddFocusRequestsProvider,
  );

  void _takeFocus() => _focus.requestFocus();

  @override
  void initState() {
    super.initState();
    _dueAt = widget.defaultDueAt;
    _listId = widget.listId;
    _focusRequests.addListener(_takeFocus);
  }

  @override
  void didUpdateWidget(QuickAddBar old) {
    super.didUpdateWidget(old);
    if (old.listId != widget.listId) _listId = widget.listId;
  }

  @override
  void dispose() {
    _focusRequests.removeListener(_takeFocus);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    // What the line itself says wins over the chips: typing "tomorrow" is
    // a later, more deliberate choice than a chip left as it was.
    final parsed = parseQuickAdd(
      text,
      now: ref.read(nowProvider)(),
      locale: Localizations.localeOf(context).toString(),
    );
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
          title: parsed.title,
          dueAt: parsed.dueAt ?? _dueAt,
          priority: parsed.priority ?? _priority,
          tags: parsed.tags,
        );
    if (!mounted) return;
    _controller.clear();
    setState(() {
      _dueAt = widget.defaultDueAt;
      _priority = 0;
    });
    final added = widget.onAdded;
    if (added != null) {
      added();
      return;
    }
    _focus.requestFocus();
  }

  Future<void> _pickDate() async {
    final now = ref.read(nowProvider)();
    final initial = _dueAt == null
        ? now
        : DateTime.fromMillisecondsSinceEpoch(_dueAt!);
    final picked = await pickDate(
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

    // macOS draws a bar like this flat, under a hairline, not on a shadow.
    final flat = context.appStyle == AppStyle.macos || widget.inSheet;
    // The chips' row: 36 px, and a finger's 48 wherever there is no
    // pointer -- the extra reaching into the gap above and the padding
    // below, so nothing moves -- and taller as larger text grows them.
    final label = Theme.of(context).textTheme.labelLarge;
    final labelSize = label?.fontSize ?? 14;
    final grown =
        (MediaQuery.textScalerOf(context).scale(labelSize) - labelSize) *
        (label?.height ?? 1.2);
    final dense =
        context.appStyle == AppStyle.macos && !StyleAdaptation.isPhone(context);
    final chipRow = max(dense ? 36.0 : kMinInteractiveDimension, 36 + grown);
    final reach = min<double>(6, (chipRow - 36) / 2);
    return Material(
      color: widget.inSheet ? Colors.transparent : scheme.surface,
      elevation: flat ? 0 : 3,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      shape: flat && !widget.inSheet
          ? Border(top: BorderSide(color: nemo.separator, width: 0.5))
          : null,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 8, 12, 8 - reach),
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
                      autofocus: widget.inSheet,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        hintText: l.tasksAddHintSmart,
                        prefixIcon: const AppIcon(Icons.add_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    key: const Key('quick-add-submit'),
                    tooltip: l.commonAdd,
                    onPressed: _submit,
                    icon: const AppIcon(Icons.arrow_upward_rounded),
                  ),
                ],
              ),
              SizedBox(height: 6 - reach),
              SizedBox(
                height: chipRow,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    ActionChip(
                      key: const Key('quick-add-date'),
                      avatar: const AppIcon(Icons.schedule_rounded, size: 18),
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
                                AppIcon(
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
                        avatar: AppIcon(
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
                                  AppIcon(
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
                          avatar: AppIcon(
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
