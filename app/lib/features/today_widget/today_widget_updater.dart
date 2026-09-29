import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:nemo/features/today_widget/today_widget_bridge.dart';
import 'package:nemo/features/today_widget/today_widget_data.dart';
import 'package:nemo_core/nemo_core.dart';

/// Hands the widget its tasks and look, and asks it to redraw -- only
/// when what it would be given differs from what it was given last.
class TodayWidgetUpdater {
  TodayWidgetUpdater(this._bridge);

  final TodayWidgetBridge _bridge;
  final _last = <String, String>{};

  /// [tasks] are the open, dated, visible tasks in Today's order.
  Future<void> pushTasks(List<Task> tasks, DateTime now) =>
      _push(WidgetKeys.tasks, encodeWidgetTasks(tasks, now));

  Future<void> pushLook(Map<String, Object> look) =>
      _push(WidgetKeys.look, jsonEncode(look));

  /// A failing widget never fails what caused the push.
  Future<void> _push(String key, String value) async {
    if (_last[key] == value) return;
    try {
      await _bridge.save(key, value);
      await _bridge.redraw();
      _last[key] = value;
    } on Object catch (error) {
      debugPrint('today widget: $error');
    }
  }
}
