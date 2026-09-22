import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nemo/features/settings/ui/settings_controller.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/utils/work_input.dart';
import 'package:nemo_core/nemo_core.dart';

/// How the task was solved, how long it took, and what it cost.
///
/// Collapsed to a single row until one of the three is recorded, so a task
/// nobody has worked yet does not carry three empty fields down the page.
class TaskWorkSection extends ConsumerStatefulWidget {
  const TaskWorkSection({required this.task, required this.save, super.key});

  final Task task;
  final Future<void> Function(Task) save;

  @override
  ConsumerState<TaskWorkSection> createState() => _TaskWorkSectionState();
}

class _TaskWorkSectionState extends ConsumerState<TaskWorkSection> {
  final _solution = TextEditingController();
  final _time = TextEditingController();
  final _cost = TextEditingController();
  final _solutionFocus = FocusNode();
  final _timeFocus = FocusNode();
  final _costFocus = FocusNode();

  /// Null until someone taps the toggle, so "never touched" falls back to
  /// [_hasAny] instead of always starting closed.
  bool? _expanded;

  /// Refreshed on every build. [dispose] needs it too, but by then the
  /// element is unmounting and `Localizations.localeOf(context)` is no
  /// longer safe to call, so it is read from here instead.
  String _locale = 'en';

  bool get _hasAny =>
      widget.task.solution.isNotEmpty ||
      widget.task.timeSpentMinutes != null ||
      widget.task.costMinor != null;

  @override
  void initState() {
    super.initState();
    for (final focus in [_solutionFocus, _timeFocus, _costFocus]) {
      focus.addListener(_saveIfUnfocused);
    }
  }

  @override
  void dispose() {
    // Saving follows the task page's own rule: on unfocus and on pop.
    // Disposing a focus node that still has primary focus can drop it from
    // the manager's dirty set before the batched notify runs, so the
    // `_saveIfUnfocused` listener is never guaranteed to fire here -- flush
    // explicitly instead, the same way `_TaskDetailScreenState.dispose`
    // flushes the title and notes fields. `_save` reads the controllers
    // synchronously before its first `await`, so this runs before they are
    // disposed below; `dispose` itself cannot await, so the write is fired
    // and forgotten rather than awaited.
    unawaited(_save());
    for (final c in [_solution, _time, _cost]) {
      c.dispose();
    }
    for (final f in [_solutionFocus, _timeFocus, _costFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  /// Never refills a field that has focus: an arriving sync would
  /// otherwise move the cursor out from under whoever is typing.
  void _fill(Task task, String locale) {
    if (!_solutionFocus.hasFocus && _solution.text != task.solution) {
      _solution.text = task.solution;
    }
    final minutes = task.timeSpentMinutes;
    if (!_timeFocus.hasFocus) {
      final shown = minutes == null ? '' : '$minutes';
      if (_time.text != shown) _time.text = shown;
    }
    final cost = task.costMinor;
    if (!_costFocus.hasFocus) {
      // Written back with the separator [locale] itself writes numbers
      // with, so an amount nobody touched still reads as that locale
      // would type it, not always with a literal dot.
      //
      // Built from integer arithmetic, never `cost / 100` as a double: a
      // double round-trips imprecisely for large minor-unit values (see
      // the `parseMinorUnits` regression this mirrors), silently changing
      // the stored amount on a redisplay nobody asked for.
      final separator = NumberFormat.decimalPattern(locale).symbols.DECIMAL_SEP;
      final shown = cost == null
          ? ''
          : '${cost ~/ 100}$separator${(cost % 100).toString().padLeft(2, '0')}';
      if (_cost.text != shown) _cost.text = shown;
    }
  }

  void _saveIfUnfocused() {
    if (_solutionFocus.hasFocus || _timeFocus.hasFocus || _costFocus.hasFocus) {
      return;
    }
    unawaited(_saveAndRefill());
  }

  /// Runs [_save], then asks for a redraw. A refusal that leaves the
  /// stored value unchanged makes no database change, so nothing else
  /// would otherwise trigger `_fill` to put the stored text back over
  /// whatever unreadable text was typed -- it would stay on screen
  /// looking like a pending edit forever. Not used from [dispose]: by
  /// then the widget is unmounting and `setState` is unsafe to call.
  Future<void> _saveAndRefill() async {
    await _save();
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    final task = widget.task;
    // An unreadable time or amount leaves what is stored alone. Writing
    // null there would turn a slip into "took no time", which is a real
    // answer somebody may have meant to record.
    final minutes = _time.text.trim().isEmpty
        ? null
        : parseMinutes(_time.text) ?? task.timeSpentMinutes;
    final cost = _cost.text.trim().isEmpty
        ? null
        : parseMinorUnits(_cost.text, locale: _locale) ?? task.costMinor;
    final updated = task.copyWith(
      solution: _solution.text,
      timeSpentMinutes: minutes,
      costMinor: cost,
    );
    if (updated == task) return;
    await widget.save(updated);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final task = widget.task;
    final locale = Localizations.localeOf(context).toLanguageTag();
    _locale = locale;
    _fill(task, locale);
    final expanded = _expanded ?? _hasAny;
    final currency = ref.watch(currencyCodeProvider);
    final summary = [
      if (task.timeSpentMinutes case final minutes?)
        formatMinutes(
          minutes,
          hoursLabel: l.tasksHours,
          minutesLabel: l.tasksMinutes,
        ),
      if (task.costMinor case final minor?)
        formatMoney(minor, currency: currency, locale: locale),
    ].join(' · ');
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          key: const Key('task-work-toggle'),
          onTap: () => setState(() => _expanded = !expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l.tasksWork,
                    style: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
                if (!expanded && summary.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      summary,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                Icon(
                  expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (expanded) ...[
          const SizedBox(height: 8),
          TextField(
            key: const Key('task-solution'),
            controller: _solution,
            focusNode: _solutionFocus,
            maxLines: null,
            minLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: l.tasksSolutionHint),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('task-time-spent'),
                  controller: _time,
                  focusNode: _timeFocus,
                  decoration: InputDecoration(hintText: l.tasksTimeSpentHint),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: const Key('task-cost'),
                  controller: _cost,
                  focusNode: _costFocus,
                  decoration: InputDecoration(hintText: l.tasksCostHint),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
