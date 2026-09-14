import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/core/theme/nemo_colors.dart';
import 'package:nemo/core/widgets/due_chip.dart';
import 'package:nemo/core/widgets/list_icons.dart';
import 'package:nemo/features/celebrations/ui/complete_task.dart';
import 'package:nemo/features/lists/ui/lists_providers.dart';
import 'package:nemo/features/photos/ui/photo_thumbnail.dart';
import 'package:nemo/features/photos/ui/photos_providers.dart';
import 'package:nemo/features/settings/ui/settings_controller.dart';
import 'package:nemo/features/tasks/ui/selected_task.dart';
import 'package:nemo/features/tasks/ui/tasks_providers.dart';
import 'package:nemo/router.dart';
import 'package:nemo_core/nemo_core.dart';

/// One task in a list: round check, title, and a row of small facts.
class TaskTile extends ConsumerWidget {
  const TaskTile({
    required this.task,
    this.showList = false,
    this.onLongPress,
    super.key,
  });

  final Task task;
  final bool showList;

  /// Offered where a long press is not already the start of a drag.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final nemo = context.nemoColors;
    final now = ref.watch(nowProvider)();
    final progress = ref.watch(subtaskProgressProvider).value?[task.id];
    final list = showList
        ? ref.watch(listByIdProvider(task.listId)).value
        : null;
    final photos = ref.watch(photoCountsProvider).value?[task.id] ?? 0;
    final firstPhoto = photos == 0
        ? null
        : ref.watch(photosByTaskProvider(task.id)).value?.firstOrNull;
    final dueAt = task.dueAt;
    final meta = <Widget>[
      if (dueAt != null)
        DueChip(
          dueAt: dueAt,
          hasTime: task.dueHasTime,
          now: now,
          done: task.done,
        ),
      if (list != null)
        MetaChip(
          icon: listIcon(list.icon),
          label: list.name,
          color: nemo.listColor(list.color),
        ),
      if (progress != null && progress.total > 0)
        MetaChip(
          icon: Icons.checklist_rounded,
          label: '${progress.done}/${progress.total}',
        ),
      for (final tag in task.tags)
        InkWell(
          key: Key('tile-tag-${task.id}-$tag'),
          borderRadius: BorderRadius.circular(6),
          onTap: () => context.push(Routes.tag(tag)),
          child: MetaChip(icon: Icons.tag_rounded, label: tag),
        ),
    ];
    final titleStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(
      decoration: task.done ? TextDecoration.lineThrough : null,
      color: task.done ? scheme.onSurfaceVariant : scheme.onSurface,
      fontWeight: FontWeight.w500,
    );
    return InkWell(
      onTap: () => openTask(context, ref, task.id),
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DoneCheck(
              done: task.done,
              color: nemo.priority(task.priority),
              onChanged: (done) => completeTask(ref, task, done: done),
              celebrate: ref.watch(celebrationsEnabledProvider),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 9),
                    child: Text(task.title, style: titleStyle),
                  ),
                  if (meta.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2, bottom: 4),
                      child: Wrap(spacing: 10, runSpacing: 2, children: meta),
                    ),
                ],
              ),
            ),
            if (firstPhoto != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, right: 4),
                child: Stack(
                  key: Key('tile-photo-${task.id}'),
                  children: [
                    PhotoThumbnail(sha256: firstPhoto.sha256, size: 40),
                    if (photos > 1)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.surface.withValues(alpha: 0.85),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(6),
                              bottomRight: Radius.circular(10),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            child: Text(
                              '+${photos - 1}',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            if (task.priority > 0)
              Padding(
                padding: const EdgeInsets.only(top: 10, right: 4),
                child: Icon(
                  Icons.flag_rounded,
                  size: 18,
                  color: nemo.priority(task.priority),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Round animated checkbox; the ring takes the priority colour.
///
/// With [celebrate], ticking it on bounces and sends a ring outwards,
/// unless the platform asks for reduced motion.
class DoneCheck extends StatefulWidget {
  const DoneCheck({
    required this.done,
    required this.onChanged,
    this.color,
    this.celebrate = false,
    super.key,
  });

  final bool done;
  final Color? color;
  final ValueChanged<bool> onChanged;
  final bool celebrate;

  @override
  State<DoneCheck> createState() => _DoneCheckState();
}

class _DoneCheckState extends State<DoneCheck>
    with SingleTickerProviderStateMixin {
  late final _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1,
        end: 1.25,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 40,
    ),
    TweenSequenceItem(
      tween: Tween<double>(
        begin: 1.25,
        end: 1,
      ).chain(CurveTween(curve: Curves.easeIn)),
      weight: 60,
    ),
  ]).animate(_bounce);

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  void _toggle() {
    if (!widget.done &&
        widget.celebrate &&
        !MediaQuery.disableAnimationsOf(context)) {
      _bounce.forward(from: 0);
    }
    widget.onChanged(!widget.done);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ring = widget.color ?? scheme.outline;
    final done = widget.done;
    return Semantics(
      checked: done,
      button: true,
      child: InkResponse(
        onTap: _toggle,
        radius: 22,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              AnimatedBuilder(
                animation: _bounce,
                builder: (context, _) {
                  final t = _bounce.value;
                  if (t == 0 || t == 1) {
                    return const SizedBox(width: 24, height: 24);
                  }
                  return Transform.scale(
                    scale: 1 + t,
                    child: Opacity(
                      opacity: 1 - t,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: scheme.primary, width: 2),
                        ),
                      ),
                    ),
                  );
                },
              ),
              ScaleTransition(
                scale: _scale,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? scheme.primary : Colors.transparent,
                    border: Border.all(
                      color: done ? scheme.primary : ring,
                      width: 2,
                    ),
                  ),
                  child: done
                      ? Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: scheme.onPrimary,
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
