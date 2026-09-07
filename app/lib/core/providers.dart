import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo_core/nemo_core.dart';
import 'package:uuid/uuid.dart';

/// Values loaded before the first frame; see `AppBootstrap.load`.
class AppBootstrap {
  const AppBootstrap({
    required this.nodeId,
    required this.hlcLast,
    required this.themeMode,
    this.serverUrl,
    this.username,
  });

  final String nodeId;
  final Hlc? hlcLast;
  final ThemeMode themeMode;
  final String? serverUrl;
  final String? username;

  static Future<AppBootstrap> load(AppDatabase db) async {
    final kv = KvStore(db);
    var nodeId = await kv.get(KvKeys.nodeId);
    if (nodeId == null) {
      nodeId = const Uuid().v4();
      await kv.set(KvKeys.nodeId, nodeId);
    }
    final last = await kv.get(KvKeys.hlcLast);
    final theme = await kv.get(KvKeys.themeMode);
    return AppBootstrap(
      nodeId: nodeId,
      hlcLast: last == null ? null : Hlc.parse(last),
      themeMode: ThemeMode.values.asNameMap()[theme] ?? ThemeMode.system,
      serverUrl: await kv.get(KvKeys.serverUrl),
      username: await kv.get(KvKeys.username),
    );
  }
}

final appDatabaseProvider = Provider<AppDatabase>(
  (_) => throw UnimplementedError('override appDatabaseProvider in main'),
);

final bootstrapProvider = Provider<AppBootstrap>(
  (_) => throw UnimplementedError('override bootstrapProvider in main'),
);

final kvStoreProvider = Provider<KvStore>(
  (ref) => KvStore(ref.watch(appDatabaseProvider)),
);

final hlcClockProvider = Provider<HlcClock>((ref) {
  final boot = ref.watch(bootstrapProvider);
  return HlcClock(node: boot.nodeId, last: boot.hlcLast);
});

/// Generates row ids; overridable for deterministic tests.
final idGeneratorProvider = Provider<String Function()>((_) => const Uuid().v4);

/// Wall clock; overridable in tests.
final nowProvider = Provider<DateTime Function()>((_) => DateTime.now);

final reminderSchedulerProvider = Provider<ReminderScheduler>(
  (_) => const NoopReminderScheduler(),
);

/// True on Android where local notifications exist.
final remindersSupportedProvider = Provider<bool>(
  (_) => !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
);
