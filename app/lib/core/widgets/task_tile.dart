import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/core/theme/app_style.dart';
import 'package:nemo/core/theme/nemo_colors.dart';
import 'package:nemo/core/widgets/app_icon.dart';
import 'package:nemo/core/widgets/due_chip.dart';
import 'package:nemo/core/widgets/list_icons.dart';
import 'package:nemo/features/celebrations/ui/complete_task.dart';
import 'package:nemo/features/lists/ui/lists_providers.dart';
import 'package:nemo/features/photos/ui/photo_thumbnail.dart';
import 'package:nemo/features/photos/ui/photos_providers.dart';
import 'package:nemo/features/settings/ui/settings_controller.dart';
import 'package:nemo/features/tasks/ui/reschedule_sheet.dart';
import 'package:nemo/features/tasks/ui/selected_task.dart';
import 'package:nemo/features/tasks/ui/task_menu.dart';
import 'package:nemo/features/tasks/ui/tasks_providers.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/router.dart';
import 'package:nemo/screens/style_adaptation.dart';
import 'package:nemo/utils/dates.dart';
import 'package:nemo/utils/format.dart';
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
    // The task open beside the list, which the arrow keys move.
    final selected = ref.watch(selectedTaskProvider) == task.id;
    ref.listen(selectedTaskProvider, (_, next) {
      if (next == task.id) _keepInView(context);
    });
    final mac = context.appStyle == AppStyle.macos;
    if (!mac) {
      return _TileBody(
        task: task,
        showList: showList,
        onLongPress: onLongPress,
        highlight: selected ? context.nemoColors.selection : null,
        radius: 12,
        selectedKey: selected,
      );
    }
    // macOS: the selection is the accent with white on it while the list
    // has the keyboard, and grey once typing has moved elsewhere, as in
    // Finder and Mail; rows between are parted by inset hairlines.
    final body = !selected
        ? _TileBody(
            task: task,
            showList: showList,
            onLongPress: onLongPress,
            radius: 8,
          )
        : ListenableBuilder(
            listenable: FocusManager.instance,
            builder: (context, _) {
              final typing =
                  FocusManager.instance.primaryFocus?.context
                      ?.findAncestorStateOfType<EditableTextState>() !=
                  null;
              final theme = Theme.of(context);
              return Theme(
                data: typing ? theme : _onAccent(theme),
                child: _TileBody(
                  task: task,
                  showList: showList,
                  onLongPress: onLongPress,
                  // Deepened where white would not read on the accent.
                  highlight: typing
                      ? context.nemoColors.selection
                      : legibleOn(theme.colorScheme.primary, [
                          theme.colorScheme.onPrimary,
                        ]),
                  radius: 8,
                  selectedKey: true,
                ),
              );
            },
          );
    return Stack(
      children: [
        body,
        if (!selected)
          Positioned(
            left: StyleAdaptation.isPhone(context) ? 46 : 38,
            right: 0,
            bottom: 0,
            child: Divider(height: 0.5, color: context.nemoColors.separator),
          ),
      ],
    );
  }

  /// [theme] for a row drawn on the accent: everything in it in the colour
  /// that reads there, the check inverted.
  static ThemeData _onAccent(ThemeData theme) {
    final scheme = theme.colorScheme;
    final on = scheme.onPrimary;
    final soft = on.withValues(alpha: 0.8);
    final nemo = theme.extension<NemoColors>()!;
    return theme.copyWith(
      colorScheme: scheme.copyWith(
        primary: on,
        onPrimary: scheme.primary,
        onSurface: on,
        onSurfaceVariant: soft,
        outline: soft,
      ),
      extensions: [
        nemo.copyWith(
          priorityLow: on,
          priorityMedium: on,
          priorityHigh: on,
          overdue: on,
          listPalette: [for (final _ in nemo.listPalette) on],
        ),
        ?theme.extension<AppStyleTheme>(),
      ],
    );
  }

  /// Scrolls just far enough to show this tile, and not at all if it is
  /// already in view: the arrow keys can select a task below the fold.
  static void _keepInView(BuildContext context) {
    final box = context.findRenderObject();
    final position = Scrollable.maybeOf(context)?.position;
    if (box == null || position == null) return;
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return;
    final atTop = viewport.getOffsetToReveal(box, 0).offset;
    final atBottom = viewport.getOffsetToReveal(box, 1).offset;
    final target = position.pixels > atTop
        ? atTop
        : position.pixels < atBottom
        ? atBottom
        : null;
    if (target == null) return;
    unawaited(
      position.animateTo(
        target.clamp(position.minScrollExtent, position.maxScrollExtent),
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      ),
    );
  }
}

/// What a [TaskTile] draws, reading its colours from the theme it is
/// built in, so a row on the accent can hand it a theme of its own.
class _TileBody extends ConsumerWidget {
  const _TileBody({
    required this.task,
    required this.showList,
    required this.radius,
    this.onLongPress,
    this.highlight,
    this.selectedKey = false,
  });

  final Task task;
  final bool showList;
  final VoidCallback? onLongPress;
  final Color? highlight;
  final double radius;
  final bool selectedKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final nemo = context.nemoColors;
    final mac = context.appStyle == AppStyle.macos;
    final phone = StyleAdaptation.isPhone(context);
    // Apple's rows are denser than Material's, a Mac's densest of all.
    final checkSize = !mac ? 24.0 : (phone ? 22.0 : 18.0);
    final rowPadding = !mac ? 6.0 : (phone ? 4.0 : 2.0);
    final now = ref.watch(nowProvider)();
    final progress = ref.watch(subtaskProgressProvider).value?[task.id];
    final list = showList
        ? ref.watch(listByIdProvider(task.listId)).value
        : null;
    final photos = ref.watch(photoCountsProvider).value?[task.id] ?? 0;
    final firstPhoto = photos == 0
        ? null
        : ref
              .watch(photosByParentProvider(PhotoParent.task, task.id))
              .value
              ?.firstOrNull;
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
      fontWeight: mac ? FontWeight.w400 : FontWeight.w500,
    );
    // The title sits level with the check's centre.
    final titleTop = checkSize / 3 + checkSize / 2 - 10;
    // The check is drawn a third of itself inside its tap target, but a
    // finger needs 48 px wherever there is no pointer: the target grows
    // into the row's own padding, so the ring stays where it was drawn.
    // Only a Mac's desktop list keeps its denser target.
    final checkExtent = max<double>(
      checkSize * 5 / 3,
      mac && !phone ? 0 : kMinInteractiveDimension,
    );
    final ringX = 8 + checkSize * 5 / 6;
    final ringY = rowPadding + checkSize * 5 / 6;
    final checkLeft = max<double>(0, ringX - checkExtent / 2);
    final checkGap = max<double>(
      0,
      8 + checkSize * 5 / 3 + 4 - checkLeft - checkExtent,
    );
    final checkTop = max<double>(0, ringY - checkExtent / 2);
    // Where the target cannot reach up far enough, as in a Mac phone's
    // tight rows, the ring moves down a little and the text with it.
    final drop = checkTop + checkExtent / 2 - ringY;
    final l = L.of(context);
    return Semantics(
      container: true,
      button: true,
      selected: selectedKey,
      label: _describe(l, Localizations.localeOf(context).toString(), now, (
        list: list,
        progress: progress,
        photos: photos,
      )),
      // What a swipe, a long press, a right click or a tag's own tap does,
      // for someone whose screen reader has taken those gestures over.
      customSemanticsActions: {
        CustomSemanticsAction(
          label: task.done ? l.taskMenuUndone : l.taskMenuDone,
        ): () =>
            unawaited(completeTask(ref, task, done: !task.done)),
        CustomSemanticsAction(label: l.taskMenuMove): () =>
            unawaited(showRescheduleSheet(context, ref, task)),
        CustomSemanticsAction(label: l.commonDelete): () =>
            unawaited(deleteTaskWithUndo(context, ref, task)),
        for (final tag in task.tags)
          CustomSemanticsAction(label: l.a11yShowTag(tag)): () =>
              unawaited(context.push(Routes.tag(tag))),
      },
      child: Material(
        key: selectedKey ? Key('selected-task-${task.id}') : null,
        color: highlight ?? Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: () => openTask(context, ref, task.id),
          onLongPress: onLongPress,
          onSecondaryTapUp: (d) =>
              showTaskMenu(context, ref, task, d.globalPosition),
          mouseCursor: context.clickCursor,
          borderRadius: BorderRadius.circular(radius),
          child: Padding(
            padding: EdgeInsets.only(left: checkLeft, right: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: checkTop),
                  child: DoneCheck(
                    done: task.done,
                    size: checkSize,
                    target: checkExtent,
                    label: l.a11yDoneCheck(task.title),
                    color: nemo.priority(task.priority),
                    onChanged: (done) => completeTask(ref, task, done: done),
                    celebrate: ref.watch(celebrationsEnabledProvider),
                  ),
                ),
                SizedBox(width: checkGap),
                // Said once, in the row's own description above.
                Expanded(
                  child: ExcludeSemantics(
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: rowPadding + drop,
                        bottom: rowPadding,
                      ),
                      child: _facts(
                        context,
                        mac: mac,
                        titleTop: titleTop,
                        titleStyle: titleStyle,
                        meta: meta,
                        firstPhoto: firstPhoto,
                        photos: photos,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The row as a screen reader says it: the title, then when it is due,
  /// how much it matters, where it is and what hangs off it.
  String _describe(
    L l,
    String locale,
    DateTime now,
    ({TaskList? list, ({int done, int total})? progress, int photos}) extra,
  ) {
    final dueAt = task.dueAt;
    final (:list, :progress, :photos) = extra;
    String? due;
    if (dueAt != null) {
      final day = dueLabel(
        l,
        locale,
        dueAt: dueAt,
        hasTime: task.dueHasTime,
        now: now,
        // A reader says the dot between day and time out loud.
      ).replaceAll(' · ', ', ');
      due =
          !task.done &&
              isOverdue(dueAt: dueAt, hasTime: task.dueHasTime, now: now)
          ? l.a11yOverdue(day)
          : l.a11yDue(day);
    }
    return [
      task.title,
      ?due,
      if (task.priority > 0)
        l.a11yPriority(switch (task.priority) {
          1 => l.priorityLow,
          2 => l.priorityMedium,
          _ => l.priorityHigh,
        }),
      if (list != null) l.a11yInList(list.isInbox ? l.listsInbox : list.name),
      if (progress != null && progress.total > 0)
        l.a11ySubtasks(progress.done, progress.total),
      if (task.tags.isNotEmpty) l.a11yTags(task.tags.join(', ')),
      if (photos > 0) l.a11yPhotos(photos),
    ].join('. ');
  }

  /// The title with its small facts beneath, and the picture and flag
  /// beside them.
  Widget _facts(
    BuildContext context, {
    required bool mac,
    required double titleTop,
    required TextStyle? titleStyle,
    required List<Widget> meta,
    required Photo? firstPhoto,
    required int photos,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final nemo = context.nemoColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: mac ? titleTop : 9),
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
            padding: EdgeInsets.only(top: mac ? titleTop : 10, right: 4),
            child: AppIcon(
              Icons.flag_rounded,
              size: mac ? 16 : 18,
              color: nemo.priority(task.priority),
            ),
          ),
      ],
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
    this.size = 24,
    this.target = kMinInteractiveDimension,
    this.label,
    super.key,
  });

  /// Across the ring.
  final double size;

  /// Across the tap target around the ring: a finger's 48 px unless a
  /// dense desktop row asks for less, and never less than a third of the
  /// ring again on each side.
  final double target;

  /// What a screen reader calls it; its ticked state is said apart.
  final String? label;

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
    // Android's apps answer a tick with a tap under the finger; a
    // celebration brings its own, so this is for the ticks without one.
    if (context.appStyle == AppStyle.material &&
        (widget.done || !widget.celebrate)) {
      unawaited(HapticFeedback.selectionClick());
    }
    widget.onChanged(!widget.done);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ring = widget.color ?? scheme.outline;
    final done = widget.done;
    // A checkbox to a screen reader, a node apart from the row it is in.
    return Semantics(
      container: true,
      checked: done,
      enabled: true,
      label: widget.label,
      child: InkResponse(
        onTap: _toggle,
        radius: widget.size * 11 / 12,
        child: Padding(
          padding: EdgeInsets.all(
            max(widget.size / 3, (widget.target - widget.size) / 2),
          ),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              AnimatedBuilder(
                animation: _bounce,
                builder: (context, _) {
                  final t = _bounce.value;
                  if (t == 0 || t == 1) {
                    return SizedBox.square(dimension: widget.size);
                  }
                  return Transform.scale(
                    scale: 1 + t,
                    child: Opacity(
                      opacity: 1 - t,
                      child: Container(
                        width: widget.size,
                        height: widget.size,
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
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? scheme.primary : Colors.transparent,
                    border: Border.all(
                      color: done ? scheme.primary : ring,
                      width: 2,
                    ),
                  ),
                  child: done
                      ? AppIcon(
                          Icons.check_rounded,
                          size: widget.size * 2 / 3,
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
