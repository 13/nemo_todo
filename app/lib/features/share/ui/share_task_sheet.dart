import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/core/theme/nemo_colors.dart';
import 'package:nemo/core/widgets/app_icon.dart';
import 'package:nemo/core/widgets/list_icons.dart';
import 'package:nemo/features/lists/ui/lists_providers.dart';
import 'package:nemo/features/photos/ui/photos_providers.dart';
import 'package:nemo/features/share/data/shared_content.dart';
import 'package:nemo/features/tasks/ui/tasks_providers.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/utils/quick_add_parser.dart';
import 'package:nemo_core/nemo_core.dart';

/// "New task", opened by a share from another app and prefilled from it.
///
/// Nothing is written until Save: cancelling, or swiping the sheet away,
/// leaves no task and no picture behind. The title reads the same
/// shorthand as quick add (`#tag`, `!high`, a trailing "tomorrow").
class ShareTaskSheet extends ConsumerStatefulWidget {
  const ShareTaskSheet({required this.draft, super.key});

  final ShareDraft draft;

  @override
  ConsumerState<ShareTaskSheet> createState() => _ShareTaskSheetState();
}

class _ShareTaskSheetState extends ConsumerState<ShareTaskSheet> {
  static const _thumb = 72.0;

  late final _title = TextEditingController(text: widget.draft.title);
  late final _notes = TextEditingController(text: widget.draft.notes);
  late final List<Uint8List> _images = [...widget.draft.images];

  /// Null until picked: the Inbox.
  String? _listId;
  var _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _title.text.trim();
    if (text.isEmpty || _saving) return;
    final l = L.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final lists = ref.read(allListsProvider).value ?? const [];
    final list =
        lists.where((x) => x.id == _listId).firstOrNull ??
        lists.where((x) => x.isInbox).firstOrNull ??
        lists.firstOrNull;
    if (list == null) return;
    final parsed = parseQuickAdd(
      text,
      now: ref.read(nowProvider)(),
      locale: Localizations.localeOf(context).toString(),
    );
    final tasks = ref.read(tasksRepositoryProvider);
    final photos = ref.read(photosRepositoryProvider);
    setState(() => _saving = true);
    final task = await tasks.create(
      listId: list.id,
      title: parsed.title,
      dueAt: parsed.dueAt,
      priority: parsed.priority ?? 0,
      tags: parsed.tags,
      notes: _notes.text.trim(),
    );
    // One at a time through the same pipeline as the camera: each is
    // decoded, turned upright and re-encoded -- which is what drops its
    // EXIF block -- before it is stored or queued for the server.
    var skipped = false;
    for (final bytes in _images) {
      if (await photos.add(PhotoParent.task, task.id, bytes) == null) {
        skipped = true;
      }
    }
    navigator.pop(true);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          l.shareTaskAdded(list.isInbox ? l.listsInbox : list.name),
        ),
      ),
    );
    if (skipped) {
      messenger.showSnackBar(SnackBar(content: Text(l.photosNotAnImage)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final scheme = Theme.of(context).colorScheme;
    final nemo = context.nemoColors;
    final lists = ref.watch(allListsProvider).value ?? const [];
    final list =
        lists.where((x) => x.id == _listId).firstOrNull ??
        lists.where((x) => x.isInbox).firstOrNull;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Column(
            key: const Key('share-sheet'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.shortcutNewTask,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('share-title'),
                controller: _title,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l.tasksTitleHint,
                  hintText: l.tasksAddHintSmart,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('share-notes'),
                controller: _notes,
                minLines: 2,
                maxLines: 6,
                decoration: InputDecoration(labelText: l.tasksNotesHint),
              ),
              if (_images.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: _thumb,
                  child: ListView(
                    key: const Key('share-photos'),
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (var i = 0; i < _images.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _SharedPhoto(
                            key: Key('share-photo-$i'),
                            bytes: _images[i],
                            size: _thumb,
                            removeLabel: l.shareRemovePhoto,
                            onRemove: _saving
                                ? null
                                : () => setState(() => _images.removeAt(i)),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: PopupMenuButton<String>(
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
                    key: const Key('share-list'),
                    avatar: AppIcon(
                      listIcon(list?.icon ?? 'inbox'),
                      size: 18,
                      color: list == null
                          ? scheme.outline
                          : nemo.listColor(list.color),
                    ),
                    label: Text(
                      list == null || list.isInbox ? l.listsInbox : list.name,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    key: const Key('share-cancel'),
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: Text(l.commonCancel),
                  ),
                  const SizedBox(width: 8),
                  ListenableBuilder(
                    listenable: _title,
                    builder: (context, _) => FilledButton(
                      key: const Key('share-save'),
                      onPressed: _saving || _title.text.trim().isEmpty
                          ? null
                          : _save,
                      child: Text(l.commonSave),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A shared picture as it arrived, before the pipeline has seen it; bytes
/// that are not a picture show as a placeholder and are skipped on save.
class _SharedPhoto extends StatelessWidget {
  const _SharedPhoto({
    required this.bytes,
    required this.size,
    required this.removeLabel,
    required this.onRemove,
    super.key,
  });

  final Uint8List bytes;
  final double size;
  final String removeLabel;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pixels = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return SizedBox.square(
      dimension: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              cacheWidth: pixels,
              errorBuilder: (_, _, _) => ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: AppIcon(Icons.image_outlined, color: scheme.outline),
              ),
            ),
          ),
          PositionedDirectional(
            top: 0,
            end: 0,
            child: IconButton(
              tooltip: removeLabel,
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                backgroundColor: scheme.surface.withValues(alpha: 0.8),
              ),
              onPressed: onRemove,
              icon: const AppIcon(Icons.close_rounded, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}
