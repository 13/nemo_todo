import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nemo/core/db/app_database.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/notifications/reminder_scheduler.dart';
import 'package:nemo/features/photos/data/photo_store.dart';
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
    this.lastSyncAt,
    this.trustedCertificates,
    this.serverVersion,
    this.celebrations = true,
    this.celebrationSound = false,
    this.achievements = true,
    this.currency = 'EUR',
  });

  final String nodeId;
  final Hlc? hlcLast;
  final ThemeMode themeMode;
  final String? serverUrl;
  final String? username;

  /// Epoch milliseconds of the last successful sync.
  final int? lastSyncAt;

  /// Certificates the user has chosen to trust, as stored by
  /// `CertificateTrust`.
  final String? trustedCertificates;

  /// What the server said it was running, last time one answered. Kept so
  /// Settings can say so before the first sync of a session, and while
  /// offline.
  final String? serverVersion;

  /// Confetti, animations and haptics when a task is completed.
  final bool celebrations;

  /// A sound for the big moments; off unless chosen.
  final bool celebrationSound;

  /// Achievements, their banners and the Settings tile.
  final bool achievements;

  /// ISO 4217 code for the amounts on a task; the device's own locale
  /// decides the default the first time.
  final String currency;

  static Future<AppBootstrap> load(AppDatabase db) async {
    final kv = KvStore(db);
    var nodeId = await kv.get(KvKeys.nodeId);
    if (nodeId == null) {
      nodeId = const Uuid().v4();
      await kv.set(KvKeys.nodeId, nodeId);
    }
    final last = await kv.get(KvKeys.hlcLast);
    final theme = await kv.get(KvKeys.themeMode);
    final lastSync = await kv.get(KvKeys.lastSyncAt);
    return AppBootstrap(
      nodeId: nodeId,
      hlcLast: last == null ? null : Hlc.parse(last),
      themeMode: ThemeMode.values.asNameMap()[theme] ?? ThemeMode.system,
      serverUrl: await kv.get(KvKeys.serverUrl),
      username: await kv.get(KvKeys.username),
      lastSyncAt: lastSync == null ? null : int.tryParse(lastSync),
      trustedCertificates: await kv.get(KvKeys.trustedCertificates),
      serverVersion: await kv.get(KvKeys.serverVersion),
      celebrations: await kv.get(KvKeys.celebrations) != 'false',
      celebrationSound: await kv.get(KvKeys.celebrationSound) == 'true',
      achievements: await kv.get(KvKeys.achievements) != 'false',
      currency: await kv.get(KvKeys.currency) ?? defaultCurrencyCode(),
    );
  }
}

/// What the device's own locale spends in, for the first run. Falls back
/// to EUR when the locale names no currency.
String defaultCurrencyCode() {
  try {
    return NumberFormat.simpleCurrency(locale: Intl.getCurrentLocale())
            .currencyName ??
        'EUR';
    // `NumberFormat.simpleCurrency` throws this -- not an `Exception` --
    // for a locale it cannot verify (`intl`'s `verifiedLocale` gives up
    // this way once its own fallbacks fail). The locale comes from the
    // device, not from this code, so it is not a programming mistake to
    // guard against here: an unknown locale gets a default the user can
    // change, which beats a crash on the first frame.
    // ignore: avoid_catching_errors
  } on ArgumentError {
    return 'EUR';
  } on Exception {
    return 'EUR';
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

/// Only Android can install an APK, so only Android offers updates.
final updatesSupportedProvider = Provider<bool>(
  (_) => !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
);

/// True on Android where local notifications exist.
final remindersSupportedProvider = Provider<bool>(
  (_) => !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
);

/// Whether the app refuses to show anything until an account is connected.
///
/// The Android app is local-first: it works on its own and an account is
/// something you add later. The web app is not -- it is opened at the
/// address of a server, by someone who has an account on it -- so there it
/// asks who you are before it shows a single task.
final authRequiredProvider = Provider<bool>((_) => kIsWeb);

/// Whether this build was handed to the user by the server it syncs with.
///
/// True on the web, where the page comes from the server and a reload is
/// what fetches a newer one. False on Android, where the app was installed
/// and a newer server means an update to download -- which the update tile
/// already offers, and which no amount of reloading would do.
final servedByServerProvider = Provider<bool>((_) => kIsWeb);

/// Whether this platform downloads pictures ahead of being asked.
///
/// Android does: the app is expected to work with the network off, and a
/// placeholder where a photo should be is exactly the offline failure the
/// app exists to avoid. The web app fetches when it shows.
final photoDownloadEagerProvider = Provider<bool>((_) => !kIsWeb);

/// Where this device keeps the bytes of pictures. Overridden in tests.
final photoStoreProvider = Provider<PhotoStore>(
  (_) => throw UnimplementedError('override photoStoreProvider in main'),
);
