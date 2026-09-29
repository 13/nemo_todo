import 'package:flutter/material.dart';

/// Brand colours outside the Material colour roles.
@immutable
class NemoColors extends ThemeExtension<NemoColors> {
  const NemoColors({
    required this.priorityLow,
    required this.priorityMedium,
    required this.priorityHigh,
    required this.overdue,
    required this.listPalette,
    required this.sidebar,
    required this.separator,
    required this.selection,
    this.tintedMetaText = true,
  });

  static const light = NemoColors(
    priorityLow: Color(0xFF2E7DD1),
    priorityMedium: Color(0xFFC77E00),
    priorityHigh: Color(0xFFE2503E),
    overdue: Color(0xFFC62828),
    listPalette: [
      Color(0xFF0E7C86),
      Color(0xFF2E7DD1),
      Color(0xFF7B57C8),
      Color(0xFFD64577),
      Color(0xFFE2503E),
      Color(0xFFC77E00),
      Color(0xFF3F9B4C),
      Color(0xFF5F6B7A),
    ],
    sidebar: Colors.white,
    separator: Color(0xFFD9E3E1),
    selection: Color(0x240E7C86),
  );

  static const dark = NemoColors(
    priorityLow: Color(0xFF7FB4F0),
    priorityMedium: Color(0xFFF2B950),
    priorityHigh: Color(0xFFF58A7A),
    overdue: Color(0xFFFF8A80),
    listPalette: [
      Color(0xFF5BC0C9),
      Color(0xFF7FB4F0),
      Color(0xFFB39BE8),
      Color(0xFFF08AB0),
      Color(0xFFF58A7A),
      Color(0xFFF2B950),
      Color(0xFF8ED39A),
      Color(0xFFA7B2C0),
    ],
    sidebar: Color(0xFF151F1F),
    separator: Color(0xFF2A3837),
    selection: Color(0x245BC0C9),
  );

  final Color priorityLow;
  final Color priorityMedium;
  final Color priorityHigh;
  final Color overdue;

  /// Eight colours a list can pick from; `TaskList.color` indexes this.
  final List<Color> listPalette;

  /// Behind the navigation where it is a panel of its own.
  final Color sidebar;

  /// Hairlines between regions and rows.
  final Color separator;

  /// Behind the selected row of a sidebar or list.
  final Color selection;

  /// Whether a task's small facts colour their text as well as their icon.
  /// Where false, only the icon carries a list's colour and the text stays
  /// secondary, which keeps light colours readable as text; a due date
  /// still colours its text, since overdue is worth reading at a glance.
  final bool tintedMetaText;

  Color listColor(int index) => listPalette[index % listPalette.length];

  /// Colour for a task priority; null for "none".
  Color? priority(int priority) => switch (priority) {
    1 => priorityLow,
    2 => priorityMedium,
    3 => priorityHigh,
    _ => null,
  };

  @override
  NemoColors copyWith({
    Color? priorityLow,
    Color? priorityMedium,
    Color? priorityHigh,
    Color? overdue,
    List<Color>? listPalette,
    Color? sidebar,
    Color? separator,
    Color? selection,
    bool? tintedMetaText,
  }) => NemoColors(
    priorityLow: priorityLow ?? this.priorityLow,
    priorityMedium: priorityMedium ?? this.priorityMedium,
    priorityHigh: priorityHigh ?? this.priorityHigh,
    overdue: overdue ?? this.overdue,
    listPalette: listPalette ?? this.listPalette,
    sidebar: sidebar ?? this.sidebar,
    separator: separator ?? this.separator,
    selection: selection ?? this.selection,
    tintedMetaText: tintedMetaText ?? this.tintedMetaText,
  );

  @override
  NemoColors lerp(NemoColors? other, double t) {
    if (other == null) return this;
    return NemoColors(
      priorityLow: Color.lerp(priorityLow, other.priorityLow, t)!,
      priorityMedium: Color.lerp(priorityMedium, other.priorityMedium, t)!,
      priorityHigh: Color.lerp(priorityHigh, other.priorityHigh, t)!,
      overdue: Color.lerp(overdue, other.overdue, t)!,
      listPalette: [
        for (var i = 0; i < listPalette.length; i++)
          Color.lerp(listPalette[i], other.listColor(i), t)!,
      ],
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      separator: Color.lerp(separator, other.separator, t)!,
      selection: Color.lerp(selection, other.selection, t)!,
      tintedMetaText: t < 0.5 ? tintedMetaText : other.tintedMetaText,
    );
  }
}

extension NemoColorsContext on BuildContext {
  NemoColors get nemoColors => Theme.of(this).extension<NemoColors>()!;
}
