import 'package:drift/native.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo_core/nemo_core.dart';

/// Fresh in-memory database for tests.
AppDatabase testDatabase() => AppDatabase(NativeDatabase.memory());

/// Deterministic ids: t1, t2, …
String Function() sequentialIds([String prefix = 'id']) {
  var n = 0;
  return () => '$prefix${++n}';
}

/// Clock frozen at a known instant so stamps are predictable.
final testNow = DateTime(2026, 9, 7, 10);

HlcClock testClock([String node = 'test']) =>
    HlcClock(node: node, now: () => testNow);
