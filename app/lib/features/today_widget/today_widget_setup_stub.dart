import 'package:flutter/foundation.dart';
import 'package:nemo/features/today_widget/today_widget_bridge.dart';

/// The web has no home-screen widget.
Future<({TodayWidgetBridge bridge, Stream<String> ticks})?> openTodayWidget(
  ValueNotifier<String?> tapped,
) async => null;
