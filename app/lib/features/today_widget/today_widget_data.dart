import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:nemo/core/theme/app_style.dart';
import 'package:nemo/core/theme/nemo_colors.dart';
import 'package:nemo/utils/dates.dart';
import 'package:nemo_core/nemo_core.dart';

/// How many days ahead the widget is given tasks for. It picks today's
/// from them itself, so it stays right across midnights the app sleeps
/// through -- a week of them, like the daily list.
const widgetHorizonDays = 8;

/// At most this many tasks are handed to the widget. It shows a handful;
/// the rest only make up its count.
const widgetMaxTasks = 200;

/// Keys in the widget's storage, read by `TodayWidgetProvider.kt`.
abstract final class WidgetKeys {
  static const tasks = 'today.tasks';
  static const look = 'today.look';
}

/// What the widget is given of [tasks] at [now]: the open, dated ones due
/// before the day [widgetHorizonDays] ahead, overdue included, in the
/// order they came (Today's), as `{id, title, due, timed}`.
List<Map<String, Object>> widgetTasks(List<Task> tasks, DateTime now) {
  final horizon = dayStartMsFrom(now, widgetHorizonDays);
  return [
    for (final t in tasks)
      if (!t.done && !t.isDeleted && t.dueAt != null && t.dueAt! < horizon)
        {'id': t.id, 'title': t.title, 'due': t.dueAt!, 'timed': t.dueHasTime},
  ].take(widgetMaxTasks).toList();
}

String encodeWidgetTasks(List<Task> tasks, DateTime now) =>
    jsonEncode(widgetTasks(tasks, now));

/// The app's look for the widget: both brightnesses, since the launcher
/// may draw it in either long after the app last ran.
///
/// [dynamic] asks the widget to take the wallpaper's colours from the
/// system itself on Android 12 and later, so it follows a new wallpaper
/// without the app; it is only true for the Material style drawn in the
/// wallpaper's colours, with no accent of the user's own.
Map<String, Object> widgetLook({
  required ThemeMode mode,
  required AppStyle style,
  required ThemeData light,
  required ThemeData dark,
  required bool hasWallpaper,
  required int? accent,
}) => {
  'mode': mode.name,
  'dynamic': style == AppStyle.material && hasWallpaper && accent == null,
  'light': _roles(light),
  'dark': _roles(dark),
};

Map<String, int> _roles(ThemeData theme) {
  final scheme = theme.colorScheme;
  final overdue = theme.extension<NemoColors>()?.overdue ?? scheme.error;
  return {
    'background': theme.scaffoldBackgroundColor.toARGB32(),
    'text': scheme.onSurface.toARGB32(),
    'secondary': scheme.onSurfaceVariant.toARGB32(),
    'accent': scheme.primary.toARGB32(),
    'overdue': overdue.toARGB32(),
  };
}
