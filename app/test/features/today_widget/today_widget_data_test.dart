import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/theme/app_style.dart';
import 'package:nemo/core/theme/app_theme.dart';
import 'package:nemo/core/theme/nemo_colors.dart';
import 'package:nemo/features/today_widget/today_widget_data.dart';
import 'package:nemo_core/nemo_core.dart';

void main() {
  final now = DateTime(2026, 9, 29, 10);
  int at(int days, [int hour = 0]) => DateTime(
    now.year,
    now.month,
    now.day + days,
    hour,
  ).millisecondsSinceEpoch;
  Task task(
    String id, {
    int? due,
    bool timed = false,
    bool done = false,
    String? deletedAt,
  }) => Task(
    id: id,
    listId: 'l',
    title: 'Title $id',
    sortKey: 'a',
    updatedAt: 'x',
    dueAt: due,
    dueHasTime: timed,
    done: done,
    deletedAt: deletedAt,
  );

  group('widgetTasks', () {
    test('keeps open dated tasks up to a week ahead, overdue included', () {
      final result = widgetTasks([
        task('overdue', due: at(-3)),
        task('today', due: at(0, 14), timed: true),
        task('tomorrow', due: at(1)),
        task('last day', due: at(widgetHorizonDays - 1, 23)),
        task('too far', due: at(widgetHorizonDays)),
      ], now);
      expect(
        [for (final t in result) t['id']],
        ['overdue', 'today', 'tomorrow', 'last day'],
      );
    });

    test('leaves out done, deleted and undated tasks', () {
      final result = widgetTasks([
        task('done', due: at(0), done: true),
        task('deleted', due: at(0), deletedAt: 'x'),
        task('undated'),
        task('open', due: at(0)),
      ], now);
      expect([for (final t in result) t['id']], ['open']);
    });

    test('keeps the order it was given', () {
      final result = widgetTasks([
        task('b', due: at(0)),
        task('a', due: at(-1)),
      ], now);
      expect([for (final t in result) t['id']], ['b', 'a']);
    });

    test('caps how many it hands over', () {
      final many = [
        for (var i = 0; i < widgetMaxTasks + 5; i++) task('$i', due: at(0)),
      ];
      expect(widgetTasks(many, now), hasLength(widgetMaxTasks));
    });

    test('encodes id, title, due instant and whether it has a time', () {
      final json = jsonDecode(
        encodeWidgetTasks([task('t', due: at(0, 9), timed: true)], now),
      );
      expect(json, [
        {'id': 't', 'title': 'Title t', 'due': at(0, 9), 'timed': true},
      ]);
    });
  });

  group('widgetLook', () {
    Map<String, Object> look({
      AppStyle style = AppStyle.nemo,
      bool hasWallpaper = false,
      int? accent,
      ThemeMode mode = ThemeMode.system,
    }) => widgetLook(
      mode: mode,
      style: style,
      light: AppTheme.build(style, Brightness.light, accent: accent),
      dark: AppTheme.build(style, Brightness.dark, accent: accent),
      hasWallpaper: hasWallpaper,
      accent: accent,
    );

    test('carries the theme mode', () {
      expect(look(mode: ThemeMode.dark)['mode'], 'dark');
      expect(look()['mode'], 'system');
    });

    test('is dynamic only for Material in the wallpaper colours', () {
      expect(
        look(style: AppStyle.material, hasWallpaper: true)['dynamic'],
        true,
      );
      expect(look(style: AppStyle.material)['dynamic'], false);
      expect(
        look(
          style: AppStyle.material,
          hasWallpaper: true,
          accent: 2,
        )['dynamic'],
        false,
      );
      expect(look(hasWallpaper: true)['dynamic'], false);
    });

    test('gives both brightnesses the theme colours as ARGB', () {
      final light = AppTheme.build(AppStyle.nemo, Brightness.light);
      final dark = AppTheme.build(AppStyle.nemo, Brightness.dark);
      final result = look();
      expect(result['light'], {
        'background': light.scaffoldBackgroundColor.toARGB32(),
        'text': light.colorScheme.onSurface.toARGB32(),
        'secondary': light.colorScheme.onSurfaceVariant.toARGB32(),
        'accent': light.colorScheme.primary.toARGB32(),
        'overdue': NemoColors.light.overdue.toARGB32(),
      });
      expect(
        (result['dark']! as Map)['accent'],
        dark.colorScheme.primary.toARGB32(),
      );
    });

    test('follows the chosen accent', () {
      final pink = AppTheme.build(AppStyle.nemo, Brightness.light, accent: 3);
      expect(
        (look(accent: 3)['light']! as Map)['accent'],
        pink.colorScheme.primary.toARGB32(),
      );
    });
  });
}
