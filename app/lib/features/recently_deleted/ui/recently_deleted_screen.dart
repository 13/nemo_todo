import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/core/widgets/app_icon.dart';
import 'package:nemo/core/widgets/async_body.dart';
import 'package:nemo/core/widgets/empty_state.dart';
import 'package:nemo/core/widgets/max_width.dart';
import 'package:nemo/core/widgets/section_header.dart';
import 'package:nemo/features/recently_deleted/data/recently_deleted_repository.dart';
import 'package:nemo/features/recently_deleted/ui/recently_deleted_providers.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/router.dart';
import 'package:nemo/utils/format.dart';
import 'package:nemo_core/nemo_core.dart';

/// Lists and tasks deleted in the last 30 days, to bring back or delete for
/// good.
class RecentlyDeletedScreen extends ConsumerWidget {
  const RecentlyDeletedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final days = tombstoneRetention.inDays;
    final deleted = ref.watch(recentlyDeletedProvider);
    final lists =
        ref.watch(recentlyDeletedListsProvider).value ?? const <DeletedList>[];
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
        data: (items) => items.isEmpty && lists.isEmpty
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
                    // Headings only when there are both, so a page of
                    // tasks alone reads as it always has.
                    if (lists.isNotEmpty) ...[
                      SectionHeader(title: l.recentlyDeletedListsHeader),
                      for (final item in lists) _DeletedListRow(item),
                      if (items.isNotEmpty)
                        SectionHeader(title: l.recentlyDeletedTasksHeader),
                    ],
                    for (final item in items) _DeletedTaskRow(item),
                  ],
                ),
              ),
      ),
    );
  }
}

class _DeletedTaskRow extends ConsumerWidget {
  const _DeletedTaskRow(this.item);

  final DeletedTask item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final task = item.task;
    final list = item.list;
    final home = list == null || list.isInbox ? l.listsInbox : list.name;
    return _DeletedRow(
      id: task.id,
      title: task.title,
      deletedAt: task.deletedAt,
      detail: l.recentlyDeletedBackTo(home),
      confirm: l.recentlyDeletedEraseConfirm(task.title),
      onRestore: () async {
        final to = await ref
            .read(recentlyDeletedRepositoryProvider)
            .restore(task.id);
        return to == null
            ? null
            : l.recentlyDeletedRestored(to.isInbox ? l.listsInbox : to.name);
      },
      onErase: () => ref.read(recentlyDeletedRepositoryProvider).erase(task.id),
    );
  }
}

class _DeletedListRow extends ConsumerWidget {
  const _DeletedListRow(this.item);

  final DeletedList item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = L.of(context);
    final list = item.list;
    return _DeletedRow(
      id: 'list-${list.id}',
      title: list.name,
      deletedAt: list.deletedAt,
      detail: l.recentlyDeletedListTasks(item.tasks),
      confirm: l.recentlyDeletedEraseListConfirm(list.name),
      onRestore: () async {
        final back = await ref
            .read(recentlyDeletedRepositoryProvider)
            .restoreList(list.id);
        return back == null ? null : l.recentlyDeletedListRestored;
      },
      onErase: () =>
          ref.read(recentlyDeletedRepositoryProvider).eraseList(list.id),
    );
  }
}

/// One deleted list or task: what it is, when it went, and the two things
/// to do with it.
class _DeletedRow extends StatelessWidget {
  const _DeletedRow({
    required this.id,
    required this.title,
    required this.deletedAt,
    required this.detail,
    required this.confirm,
    required this.onRestore,
    required this.onErase,
  });

  /// Keys the row and its buttons: `deleted-<id>`, `restore-<id>`,
  /// `erase-<id>`.
  final String id;
  final String title;
  final String? deletedAt;
  final String detail;

  /// Asked before [onErase].
  final String confirm;

  /// Brings it back and answers what to say, or null for nothing.
  final Future<String?> Function() onRestore;
  final Future<void> Function() onErase;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).toString();
    final millis = _deletedMillis(deletedAt);
    final when = millis == null ? null : dateLabel(locale, millis);
    final error = Theme.of(context).colorScheme.error;
    return ListTile(
      key: Key('deleted-$id'),
      title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [if (when != null) l.recentlyDeletedOn(when), detail].join(' · '),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: Key('restore-$id'),
            tooltip: l.recentlyDeletedRestore,
            icon: const AppIcon(Icons.undo_rounded),
            onPressed: () => _restore(context),
          ),
          IconButton(
            key: Key('erase-$id'),
            tooltip: l.recentlyDeletedEraseNow,
            icon: AppIcon(Icons.delete_outline_rounded, color: error),
            onPressed: () => _erase(context),
          ),
        ],
      ),
    );
  }

  Future<void> _restore(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final said = await onRestore();
    if (said != null) _tell(messenger, said);
  }

  Future<void> _erase(BuildContext context) async {
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.recentlyDeletedEraseNow),
        content: Text(confirm),
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
    await onErase();
    _tell(messenger, l.recentlyDeletedErased);
  }

  /// Replaces what the last one said rather than queueing behind it: going
  /// down the page restoring one after another should answer each.
  static void _tell(ScaffoldMessengerState messenger, String text) => messenger
    ..removeCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  /// When it was deleted, from its tombstone's stamp.
  static int? _deletedMillis(String? stamp) {
    if (stamp == null) return null;
    try {
      return Hlc.parse(stamp).millis;
    } on FormatException {
      return null;
    }
  }
}
