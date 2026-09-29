import 'package:flutter/material.dart';
import 'package:nemo/core/theme/app_style.dart';
import 'package:nemo/core/widgets/app_icon.dart';
import 'package:nemo/core/widgets/presentation.dart';
import 'package:nemo/features/tasks/ui/custom_repeat_dialog.dart';
import 'package:nemo/features/tasks/ui/task_detail_sections.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/utils/format.dart';
import 'package:nemo_core/nemo_core.dart';

/// How often the task comes back.
class TaskRepeatSection extends StatelessWidget {
  const TaskRepeatSection({required this.task, required this.save, super.key});

  final Task task;
  final TaskSaver save;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).toString();
    final dueAt = task.dueAt;
    final choices = _repeatChoices(l, locale, dueAt);
    final rule = task.repeatRule;
    // A rule the chips do not name -- every three days, the second
    // Tuesday -- is shown on the custom chip rather than on none of them.
    final custom = rule != null && choices.every((c) => c.$1 != rule);
    if (context.appStyle == AppStyle.macos) {
      return _RepeatPopUp(task: task, save: save, choices: choices);
    }
    if (context.appStyle == AppStyle.material) {
      return _RepeatSheetRow(task: task, save: save, choices: choices);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DetailLabel(l.tasksRepeat),
        // Same chips as the priority row below, for the same reason: the
        // labels do not fit across a phone in one segmented row.
        Wrap(
          key: const Key('task-repeat'),
          spacing: 8,
          children: [
            for (final (choice, label) in choices)
              ChoiceChip(
                key: Key(_repeatKey(choice)),
                selected: rule == choice,
                showCheckmark: false,
                avatar: choice == null
                    ? null
                    : const AppIcon(Icons.repeat_rounded, size: 18),
                label: Text(label),
                // A rule with no date to count from would never come back,
                // so the row waits for one.
                onSelected: dueAt == null
                    ? null
                    : (_) => save(task.copyWith(repeat: choice?.encode())),
              ),
            ChoiceChip(
              key: const Key('repeat-custom'),
              selected: custom,
              showCheckmark: false,
              avatar: const AppIcon(Icons.tune_rounded, size: 18),
              label: Text(
                custom ? describeRepeat(l, locale, rule) : l.repeatCustom,
              ),
              onSelected: dueAt == null
                  ? null
                  : (_) async {
                      final picked = await showCustomRepeatDialog(
                        context,
                        due: DateTime.fromMillisecondsSinceEpoch(dueAt),
                        initial: rule,
                      );
                      if (picked != null) {
                        await save(task.copyWith(repeat: picked.encode()));
                      }
                    },
            ),
            // A rule this version cannot read -- written by a newer app, or
            // by hand -- is shown as it stands rather than as no rule at
            // all, which would say the task does not repeat.
            if (task.repeat != null && task.repeatRule == null)
              ChoiceChip(
                key: const Key('repeat-unreadable'),
                selected: true,
                showCheckmark: false,
                avatar: const AppIcon(Icons.repeat_rounded, size: 18),
                label: Text(task.repeat!),
              ),
          ],
        ),
        if (dueAt == null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l.tasksRepeatNeedsDue,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

/// The macOS style's repeat: one pop-up button naming the rule, as a Mac
/// app offers a choice of many, rather than a wall of chips.
class _RepeatPopUp extends StatelessWidget {
  const _RepeatPopUp({
    required this.task,
    required this.save,
    required this.choices,
  });

  final Task task;
  final TaskSaver save;
  final List<(Repeat?, String)> choices;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).toString();
    final scheme = Theme.of(context).colorScheme;
    final dueAt = task.dueAt;
    final rule = task.repeatRule;
    final named = choices.where((c) => c.$1 == rule).firstOrNull;
    final current = task.repeat != null && rule == null
        ? task.repeat!
        : named?.$2 ?? describeRepeat(l, locale, rule!);
    // Past the named rules: the custom dialog.
    final customIndex = choices.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DetailLabel(l.tasksRepeat),
        Align(
          alignment: Alignment.centerLeft,
          child: PopupMenuButton<int>(
            key: const Key('task-repeat'),
            enabled: dueAt != null,
            tooltip: l.tasksRepeat,
            position: PopupMenuPosition.under,
            onSelected: (i) async {
              if (i < customIndex) {
                await save(task.copyWith(repeat: choices[i].$1?.encode()));
                return;
              }
              final picked = await showCustomRepeatDialog(
                context,
                due: DateTime.fromMillisecondsSinceEpoch(dueAt!),
                initial: rule,
              );
              if (picked != null) {
                await save(task.copyWith(repeat: picked.encode()));
              }
            },
            itemBuilder: (_) => [
              for (final (i, (choice, label)) in choices.indexed)
                CheckedPopupMenuItem(
                  key: Key(_repeatKey(choice)),
                  value: i,
                  // By what is stored, so an unreadable rule ticks none.
                  checked: task.repeat == choice?.encode(),
                  child: Text(label),
                ),
              const PopupMenuDivider(),
              CheckedPopupMenuItem(
                key: const Key('repeat-custom'),
                value: customIndex,
                checked: named == null && rule != null,
                child: Text(l.repeatCustom),
              ),
            ],
            child: DecoratedBox(
              decoration: ShapeDecoration(
                shape: StadiumBorder(
                  side: BorderSide(
                    color: scheme.outline.withValues(alpha: 0.35),
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppIcon(
                      Icons.repeat_rounded,
                      size: 18,
                      color: dueAt == null
                          ? scheme.onSurfaceVariant
                          : scheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      current,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: dueAt == null ? scheme.onSurfaceVariant : null,
                      ),
                    ),
                    const SizedBox(width: 4),
                    AppIcon(
                      Icons.unfold_more_rounded,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (dueAt == null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l.tasksRepeatNeedsDue,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

/// The Material style's repeat: a row naming the rule, opening a sheet of
/// choices with a radio each, as Android's own apps offer one of many.
class _RepeatSheetRow extends StatelessWidget {
  const _RepeatSheetRow({
    required this.task,
    required this.save,
    required this.choices,
  });

  final Task task;
  final TaskSaver save;
  final List<(Repeat?, String)> choices;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).toString();
    final dueAt = task.dueAt;
    final rule = task.repeatRule;
    final named = choices.where((c) => c.$1 == rule).firstOrNull;
    final current = task.repeat != null && rule == null
        ? task.repeat!
        : named?.$2 ?? describeRepeat(l, locale, rule!);
    // By what is stored, so an unreadable rule selects none.
    final selected = choices.indexWhere((c) => task.repeat == c.$1?.encode());
    final custom = choices.length;
    Future<void> pick() async {
      final picked = await showAppSheet<int>(
        context: context,
        showDragHandle: true,
        // Ten choices are more than a sheet's height on a phone: it scrolls.
        builder: (sheet) => SafeArea(
          child: SingleChildScrollView(
            child: RadioGroup<int>(
              groupValue: selected >= 0
                  ? selected
                  : (rule != null ? custom : null),
              onChanged: (i) => Navigator.pop(sheet, i),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (i, (choice, label)) in choices.indexed)
                    RadioListTile<int>(
                      key: Key(_repeatKey(choice)),
                      value: i,
                      title: Text(label),
                    ),
                  RadioListTile<int>(
                    key: const Key('repeat-custom'),
                    value: custom,
                    title: Text(l.repeatCustom),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (picked == null || !context.mounted) return;
      if (picked < custom) {
        await save(task.copyWith(repeat: choices[picked].$1?.encode()));
        return;
      }
      final made = await showCustomRepeatDialog(
        context,
        due: DateTime.fromMillisecondsSinceEpoch(dueAt!),
        initial: rule,
      );
      if (made != null) await save(task.copyWith(repeat: made.encode()));
    }

    return ListTile(
      key: const Key('task-repeat'),
      contentPadding: EdgeInsets.zero,
      enabled: dueAt != null,
      leading: const AppIcon(Icons.repeat_rounded),
      title: Text(l.tasksRepeat),
      subtitle: Text(dueAt == null ? l.tasksRepeatNeedsDue : current),
      trailing: const AppIcon(Icons.chevron_right_rounded),
      onTap: pick,
    );
  }
}

/// The rules the picker offers, in the order they read.
///
/// "The last Friday of the month" only makes sense once there is a date to
/// take the weekday from, so it follows the due date rather than being
/// offered as a fixed choice.
List<(Repeat?, String)> _repeatChoices(L l, String locale, int? dueAt) {
  final due = dueAt == null ? null : DateTime.fromMillisecondsSinceEpoch(dueAt);
  return [
    (null, l.repeatNever),
    (Repeats.daily, l.repeatDaily),
    (Repeats.weekdays, l.repeatWeekdays),
    (Repeats.weekly, l.repeatWeekly),
    (Repeats.fortnightly, l.repeatFortnightly),
    (Repeats.monthly, l.repeatMonthly),
    if (due != null)
      (
        NthWeekdayRepeat(ordinal: NthWeekdayRepeat.last, weekday: due.weekday),
        l.repeatLastWeekday(weekdayName(locale, due)),
      ),
    (Repeats.yearly, l.repeatYearly),
  ];
}

/// A widget key that survives the rule's text: `every:2w` is not a key.
String _repeatKey(Repeat? rule) =>
    'repeat-${rule?.encode().replaceAll(RegExp('[^a-z0-9]+'), '-') ?? 'never'}';
