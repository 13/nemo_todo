import 'dart:async';

/// What the app needs of the home-screen widget, behind an interface so
/// what reaches the widget can be tested without a device. The real one,
/// `HomeWidgetBridge`, is only ever imported on Android.
abstract interface class TodayWidgetBridge {
  /// Stores [value] under [key] where the widget reads it.
  Future<void> save(String key, String value);

  /// Asks every placed Today widget to draw itself again.
  Future<void> redraw();

  /// The URI of the widget tap that started the app, if one did.
  Future<Uri?> launchUri();

  /// Widget taps while the app runs.
  Stream<Uri?> get clicks;

  /// Makes [callback] the handler of the widget's background taps.
  Future<void> registerTicks(FutureOr<void> Function(Uri?) callback);
}
