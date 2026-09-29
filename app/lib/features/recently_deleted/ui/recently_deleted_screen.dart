import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/core/widgets/app_icon.dart';
import 'package:nemo/core/widgets/async_body.dart';
import 'package:nemo/core/widgets/empty_state.dart';
import 'package:nemo/core/widgets/max_width.dart';
import 'package:nemo/features/recently_deleted/data/recently_deleted_repository.dart';
import 'package:nemo/features/recently_deleted/ui/recently_deleted_providers.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/router.dart';
import 'package:nemo/utils/format.dart';
import 'package:nemo_core/nemo_core.dart';

/// Tasks deleted in the last 30 days, to bring back or delete for good.
class RecentlyDeletedScreen extends ConsumerWidget {
  const RecentlyDeletedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final days = tombstoneRetention.inDays;
    final deleted = ref.watch(recentlyDeletedProvider);
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go(Routes.lists),
        ),
        title: Text(l.recentlyDeletedTitle),
      ),
      body: AsyncBody(
        value: deleted,
        data: (items) => items.isEmpty
            ? EmptyState(
                icon: Icons.delete_outline_rounded,
                message: l.recentlyDeletedEmpty(days),
              )
            : MaxWidth(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Text(
                        l.recentlyDeletedHint(days),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    for (final item in items) _DeletedRow(item),
                  ],
                ),
              ),
      ),
    );
  }
}

class _DeletedRow extends ConsumerWidget {
  const _DeletedRow(this.item);

  final DeletedTask item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final task = item.task;
    final list = item.list;
    final home = list == null || list.isInbox ? l.listsInbox : list.name;
    final locale = Localizations.localeOf(context).toString();
    final millis = _deletedMillis(task);
    final when = millis == null ? null : dateLabel(locale, millis);
    final error = Theme.of(context).colorScheme.error;
    return ListTile(
      key: Key('deleted-${task.id}'),
      title: Text(task.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          if (when != null) l.recentlyDeletedOn(when),
          l.recentlyDeletedBackTo(home),
        ].join(' · '),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: Key('restore-${task.id}'),
            tooltip: l.recentlyDeletedRestore,
            icon: const AppIcon(Icons.undo_rounded),
            onPressed: () => _restore(context, ref),
          ),
          IconButton(
            key: Key('erase-${task.id}'),
            tooltip: l.recentlyDeletedEraseNow,
            icon: AppIcon(Icons.delete_outline_rounded, color: error),
            onPressed: () => _erase(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final to = await ref
        .read(recentlyDeletedRepositoryProvider)
        .restore(item.task.id);
    if (to == null) return;
    _tell(
      messenger,
      l.recentlyDeletedRestored(to.isInbox ? l.listsInbox : to.name),
    );
  }

  Future<void> _erase(BuildContext context, WidgetRef ref) async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.recentlyDeletedEraseNow),
        content: Text(l.recentlyDeletedEraseConfirm(item.task.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            key: const Key('confirm-erase'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.commonDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(recentlyDeletedRepositoryProvider).erase(item.task.id);
    _tell(messenger, l.recentlyDeletedErased);
  }

  /// Replaces what the last one said rather than queueing behind it: going
  /// down the page restoring one task after another should answer each.
  static void _tell(ScaffoldMessengerState messenger, String text) => messenger
    ..removeCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  /// When the task was deleted, from its tombstone's stamp.
  static int? _deletedMillis(Task task) {
    final stamp = task.deletedAt;
    if (stamp == null) return null;
    try {
      return Hlc.parse(stamp).millis;
    } on FormatException {
      return null;
    }
  }
}
