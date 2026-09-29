import 'dart:async';
import 'dart:convert';

import 'package:nemo/features/today_widget/today_widget_bridge.dart';
import 'package:nemo/features/today_widget/today_widget_data.dart';

/// Records what the app handed the home-screen widget.
class FakeWidgetBridge implements TodayWidgetBridge {
  final saved = <String, String>{};
  final saves = <String>[];
  int redraws = 0;
  Uri? launch;
  final clickController = StreamController<Uri?>.broadcast();
  FutureOr<void> Function(Uri?)? ticks;
  bool failSave = false;

  /// The tasks last handed over, decoded.
  List<Map<String, Object?>> get tasks => [
    for (final t in jsonDecode(saved[WidgetKeys.tasks] ?? '[]') as List)
      (t as Map).cast<String, Object?>(),
  ];

  List<String> get taskIds => [for (final t in tasks) t['id']! as String];

  Map<String, Object?> get look =>
      (jsonDecode(saved[WidgetKeys.look]!) as Map).cast<String, Object?>();

  int savesOf(String key) => saves.where((k) => k == key).length;

  @override
  Future<void> save(String key, String value) async {
    if (failSave) throw StateError('no widget');
    saved[key] = value;
    saves.add(key);
  }

  @override
  Future<void> redraw() async => redraws++;

  @override
  Future<Uri?> launchUri() async => launch;

  @override
  Stream<Uri?> get clicks => clickController.stream;

  @override
  Future<void> registerTicks(FutureOr<void> Function(Uri?) callback) async =>
      ticks = callback;
}
