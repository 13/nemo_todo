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
  });

  static const light = NemoColors(
    priorityLow: Color(0xFF2E7DD1),
    priorityMedium: Color(0xFFD98A00),
    priorityHigh: Color(0xFFE2503E),
    overdue: Color(0xFFC62828),
    listPalette: [
      Color(0xFF0E7C86),
      Color(0xFF2E7DD1),
      Color(0xFF7B57C8),
      Color(0xFFD64577),
      Color(0xFFE2503E),
      Color(0xFFD98A00),
      Color(0xFF3F9B4C),
      Color(0xFF5F6B7A),
    ],
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
  );

  final Color priorityLow;
  final Color priorityMedium;
  final Color priorityHigh;
  final Color overdue;

  /// Eight colours a list can pick from; `TaskList.color` indexes this.
  final List<Color> listPalette;

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
  }) => NemoColors(
    priorityLow: priorityLow ?? this.priorityLow,
    priorityMedium: priorityMedium ?? this.priorityMedium,
    priorityHigh: priorityHigh ?? this.priorityHigh,
    overdue: overdue ?? this.overdue,
    listPalette: listPalette ?? this.listPalette,
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
    );
  }
}

extension NemoColorsContext on BuildContext {
  NemoColors get nemoColors => Theme.of(this).extension<NemoColors>()!;
}
