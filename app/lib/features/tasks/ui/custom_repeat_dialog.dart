import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/utils/format.dart';
import 'package:nemo_core/nemo_core.dart';

/// Asks for a rule the chips do not offer: every N days, weeks, months or
/// years, or the nth weekday of each month. Null when dismissed.
Future<Repeat?> showCustomRepeatDialog(
  BuildContext context, {
  required DateTime due,
  Repeat? initial,
}) => showDialog<Repeat>(
  context: context,
  builder: (_) => _CustomRepeatDialog(due: due, initial: initial),
);

/// How a rule reads in a sentence, in the user's language.
String describeRepeat(L l, String locale, Repeat rule) => switch (rule) {
  EveryRepeat(:final interval, :final unit) => switch (unit) {
    RepeatUnit.day => l.repeatEveryDays(interval),
    RepeatUnit.week => l.repeatEveryWeeks(interval),
    RepeatUnit.month => l.repeatEveryMonths(interval),
    RepeatUnit.year => l.repeatEveryYears(interval),
  },
  WeekdaysRepeat() => l.repeatWeekdays,
  NthWeekdayRepeat(:final ordinal, :final weekday) => l.repeatNthWeekday(
    _ordinalKey(ordinal),
    weekdayName(locale, _aDayThatIs(weekday)),
  ),
};

/// The key the catalogue's `select` messages use for an ordinal.
String _ordinalKey(int ordinal) => switch (ordinal) {
  1 => 'first',
  2 => 'second',
  3 => 'third',
  4 => 'fourth',
  _ => 'last',
};

/// Some date falling on [weekday], to hand to a date formatter for its name.
/// 1 January 2024 was a Monday.
DateTime _aDayThatIs(int weekday) => DateTime(2024, 1, weekday);

enum _Mode { interval, weekday }

class _CustomRepeatDialog extends StatefulWidget {
  const _CustomRepeatDialog({required this.due, this.initial});

  final DateTime due;
  final Repeat? initial;

  @override
  State<_CustomRepeatDialog> createState() => _CustomRepeatDialogState();
}

class _CustomRepeatDialogState extends State<_CustomRepeatDialog> {
  late _Mode _mode;
  late final TextEditingController _interval;
  late RepeatUnit _unit;
  late int _ordinal;
  late int _weekday;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    // Starts from the rule the task already has, and otherwise from the
    // due date: "the second Tuesday" is the guess for a task due on one.
    final nth = (widget.due.day - 1) ~/ 7 + 1;
    _mode = initial is NthWeekdayRepeat ? _Mode.weekday : _Mode.interval;
    _interval = TextEditingController(
      text: '${initial is EveryRepeat ? initial.interval : 2}',
    );
    _unit = initial is EveryRepeat ? initial.unit : RepeatUnit.day;
    _ordinal = initial is NthWeekdayRepeat
        ? initial.ordinal
        : nth > 4
        ? NthWeekdayRepeat.last
        : nth;
    _weekday = initial is NthWeekdayRepeat
        ? initial.weekday
        : widget.due.weekday;
  }

  @override
  void dispose() {
    _interval.dispose();
    super.dispose();
  }

  /// The rule the form describes, or null while the interval is not one
  /// the grammar can store.
  Repeat? get _rule {
    if (_mode == _Mode.weekday) {
      return NthWeekdayRepeat(ordinal: _ordinal, weekday: _weekday);
    }
    final n = int.tryParse(_interval.text);
    if (n == null || n < 1 || n > 999) return null;
    return EveryRepeat(n, _unit);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final locale = Localizations.localeOf(context).toString();
    final rule = _rule;
    return AlertDialog(
      title: Text(l.repeatCustomTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<_Mode>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(
                value: _Mode.interval,
                label: Text(
                  l.repeatModeInterval,
                  key: const Key('repeat-mode-interval'),
                ),
              ),
              ButtonSegment(
                value: _Mode.weekday,
                label: Text(
                  l.repeatModeWeekday,
                  key: const Key('repeat-mode-weekday'),
                ),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          const SizedBox(height: 16),
          if (_mode == _Mode.interval)
            Row(
              children: [
                Text(l.repeatEvery),
                const SizedBox(width: 12),
                SizedBox(
                  width: 64,
                  child: TextField(
                    key: const Key('repeat-interval'),
                    controller: _interval,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                    ],
                    textAlign: TextAlign.center,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<RepeatUnit>(
                    key: const Key('repeat-unit'),
                    isExpanded: true,
                    value: _unit,
                    items: [
                      for (final (unit, label) in [
                        (RepeatUnit.day, l.repeatUnitDays),
                        (RepeatUnit.week, l.repeatUnitWeeks),
                        (RepeatUnit.month, l.repeatUnitMonths),
                        (RepeatUnit.year, l.repeatUnitYears),
                      ])
                        DropdownMenuItem(value: unit, child: Text(label)),
                    ],
                    onChanged: (u) => setState(() => _unit = u ?? _unit),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: DropdownButton<int>(
                    key: const Key('repeat-ordinal'),
                    isExpanded: true,
                    value: _ordinal,
                    items: [
                      for (final ordinal in [1, 2, 3, 4, NthWeekdayRepeat.last])
                        DropdownMenuItem(
                          value: ordinal,
                          child: Text(l.repeatOrdinal(_ordinalKey(ordinal))),
                        ),
                    ],
                    onChanged: (o) => setState(() => _ordinal = o ?? _ordinal),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<int>(
                    key: const Key('repeat-weekday'),
                    isExpanded: true,
                    value: _weekday,
                    items: [
                      for (
                        var day = DateTime.monday;
                        day <= DateTime.sunday;
                        day++
                      )
                        DropdownMenuItem(
                          value: day,
                          child: Text(weekdayName(locale, _aDayThatIs(day))),
                        ),
                    ],
                    onChanged: (d) => setState(() => _weekday = d ?? _weekday),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 16),
          Text(
            rule == null ? '' : describeRepeat(l, locale, rule),
            key: const Key('repeat-custom-preview'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          key: const Key('repeat-custom-save'),
          onPressed: rule == null ? null : () => Navigator.pop(context, rule),
          child: Text(l.commonSave),
        ),
      ],
    );
  }
}
