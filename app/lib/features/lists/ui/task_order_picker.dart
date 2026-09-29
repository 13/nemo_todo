import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/theme/app_style.dart';
import 'package:nemo/core/widgets/app_icon.dart';
import 'package:nemo/core/widgets/presentation.dart';
import 'package:nemo/features/lists/ui/lists_providers.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo_core/nemo_core.dart';

/// What [order] is called in the menus and the banner.
String taskOrderLabel(L l, TaskOrder order) => switch (order) {
  TaskOrder.manual => l.taskOrderManual,
  TaskOrder.dueDate => l.taskOrderDueDate,
  TaskOrder.priority => l.taskOrderPriority,
  TaskOrder.title => l.taskOrderTitle,
  TaskOrder.added => l.taskOrderAdded,
};

/// Whether this device may change how [list] is sorted: the sort is a field
/// of the list row, which the server takes only from the list's owner.
bool canSortList(WidgetRef ref, TaskList list) =>
    ref.read(listMetaProvider).value?[list.id]?.isOwner ?? true;

/// Asks how [list] should be sorted, the current choice ticked, and saves
/// the answer for every device and member.
///
/// A sheet as the window shows one: a panel from the top on a Mac, a
/// bottom sheet elsewhere.
Future<void> chooseTaskOrder(
  BuildContext context,
  WidgetRef ref,
  TaskList list,
) async {
  final l = L.of(context);
  final repo = ref.read(listsRepositoryProvider);
  final picked = await showAppSheet<TaskOrder>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
            child: Text(
              l.listsSortBy,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          for (final order in TaskOrder.values)
            ListTile(
              key: Key('task-order-${order.name}'),
              title: Text(taskOrderLabel(l, order)),
              selected: order == list.order,
              trailing: order == list.order
                  ? const AppIcon(Icons.check_rounded)
                  : null,
              onTap: () => Navigator.pop(context, order),
            ),
        ],
      ),
    ),
  );
  if (picked != null) await repo.setTaskOrder(list.id, picked);
}

/// The line above a sorted list's tasks: which order is on, and a tap
/// away from changing it. Nothing while the list is in manual order.
class TaskOrderBanner extends ConsumerWidget {
  const TaskOrderBanner({required this.list, super.key});

  final TaskList list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (list.order == TaskOrder.manual) return const SizedBox.shrink();
    final l = L.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final canSort = canSortList(ref, list);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Semantics(
          button: canSort,
          child: InkWell(
            key: const Key('task-order-banner'),
            mouseCursor: canSort ? context.clickCursor : null,
            borderRadius: BorderRadius.circular(8),
            onTap: canSort ? () => chooseTaskOrder(context, ref, list) : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: kMinInteractiveDimension,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIcon(
                      Icons.sort_rounded,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        l.taskOrderBanner(taskOrderLabel(l, list.order)),
                        style: text.labelLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
