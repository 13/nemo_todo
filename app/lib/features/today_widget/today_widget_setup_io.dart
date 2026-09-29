import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:nemo/features/today_widget/home_widget_bridge.dart';
import 'package:nemo/features/today_widget/today_widget_bridge.dart';
import 'package:nemo/features/today_widget/today_widget_links.dart';
import 'package:nemo/features/today_widget/today_widget_tick.dart';

/// Connects the Today widget before the first frame, on Android only:
/// registers the background tick, routes the tap that started the app and
/// those while it runs into [tapped] (the notifier a tapped notification
/// also uses), and opens the port background ticks are reported to.
///
/// Null elsewhere, and when the plugin will not answer.
Future<({TodayWidgetBridge bridge, Stream<String> ticks})?> openTodayWidget(
  ValueNotifier<String?> tapped,
) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
  const bridge = HomeWidgetBridge();
  try {
    await bridge.registerTicks(todayWidgetBackground);
    final launched = widgetRoute(await bridge.launchUri());
    if (launched != null) tapped.value = launched;
    bridge.clicks.listen((uri) {
      final route = widgetRoute(uri);
      if (route != null) tapped.value = route;
    });
  } on Object catch (error) {
    debugPrint('today widget: $error');
    return null;
  }
  final port = ReceivePort();
  // A mapping left behind by an earlier run of the app in this process.
  IsolateNameServer.removePortNameMapping(widgetTicksPortName);
  IsolateNameServer.registerPortWithName(port.sendPort, widgetTicksPortName);
  return (
    bridge: bridge,
    ticks: port.where((m) => m is String).cast<String>().asBroadcastStream(),
  );
}
