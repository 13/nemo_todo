import 'dart:async';

import 'package:home_widget/home_widget.dart';
import 'package:nemo/features/today_widget/today_widget_bridge.dart';

/// The real widget, through `home_widget`.
class HomeWidgetBridge implements TodayWidgetBridge {
  const HomeWidgetBridge();

  /// The Kotlin class drawing the widget.
  static const provider = 'dev.ben.nemo.TodayWidgetProvider';

  @override
  Future<void> save(String key, String value) =>
      HomeWidget.saveWidgetData<String>(key, value);

  @override
  Future<void> redraw() =>
      HomeWidget.updateWidget(qualifiedAndroidName: provider);

  @override
  Future<Uri?> launchUri() => HomeWidget.initiallyLaunchedFromHomeWidget();

  @override
  Stream<Uri?> get clicks => HomeWidget.widgetClicked;

  @override
  Future<void> registerTicks(FutureOr<void> Function(Uri?) callback) =>
      HomeWidget.registerInteractivityCallback(callback);
}
