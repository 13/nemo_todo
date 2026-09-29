import 'package:flutter/material.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/core/splash/splash.dart';
import 'package:nemo/core/theme/app_style.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_controller.g.dart';

/// Theme preference, persisted in the key-value store.
@Riverpod(keepAlive: true)
class ThemeModeController extends _$ThemeModeController {
  @override
  ThemeMode build() => ref.watch(bootstrapProvider).themeMode;

  Future<void> set(ThemeMode mode) async {
    state = mode;
    rememberTheme(mode.name);
    await ref.read(kvStoreProvider).set(KvKeys.themeMode, mode.name);
  }
}

/// Which [AppStyle] the app is drawn in, persisted in the key-value store.
@Riverpod(keepAlive: true)
class AppStyleController extends _$AppStyleController {
  @override
  AppStyle build() => ref.watch(bootstrapProvider).appStyle;

  Future<void> set(AppStyle style) async {
    state = style;
    rememberStyle(style.name);
    await ref.read(kvStoreProvider).set(KvKeys.appStyle, style.name);
  }
}

/// The accent chosen in Settings, or null for the style's own.
@Riverpod(keepAlive: true)
class AccentController extends _$AccentController {
  @override
  int? build() => ref.watch(bootstrapProvider).accent;

  Future<void> set(int? accent) async {
    state = accent;
    // A null value reads back as no accent: the style's own.
    await ref.read(kvStoreProvider).set(KvKeys.accent, accent?.toString());
  }
}

/// Confetti, animations and haptics on completing a task.
@Riverpod(keepAlive: true)
class CelebrationsEnabled extends _$CelebrationsEnabled {
  @override
  bool build() => ref.watch(bootstrapProvider).celebrations;

  Future<void> set({required bool enabled}) async {
    state = enabled;
    await ref.read(kvStoreProvider).set(KvKeys.celebrations, '$enabled');
  }
}

/// A sound for a cleared day or an unlocked achievement.
@Riverpod(keepAlive: true)
class CelebrationSoundEnabled extends _$CelebrationSoundEnabled {
  @override
  bool build() => ref.watch(bootstrapProvider).celebrationSound;

  Future<void> set({required bool enabled}) async {
    state = enabled;
    await ref.read(kvStoreProvider).set(KvKeys.celebrationSound, '$enabled');
  }
}

/// Achievements, their unlock banners and their Settings tile.
@Riverpod(keepAlive: true)
class AchievementsEnabled extends _$AchievementsEnabled {
  @override
  bool build() => ref.watch(bootstrapProvider).achievements;

  Future<void> set({required bool enabled}) async {
    state = enabled;
    await ref.read(kvStoreProvider).set(KvKeys.achievements, '$enabled');
  }
}

/// Which currency the amounts on a task are written in.
@Riverpod(keepAlive: true)
class CurrencyCode extends _$CurrencyCode {
  @override
  String build() => ref.watch(bootstrapProvider).currency;

  Future<void> set(String code) async {
    state = code;
    await ref.read(kvStoreProvider).set(KvKeys.currency, code);
  }
}

/// A morning notification with what is due; off unless chosen.
@Riverpod(keepAlive: true)
class DailyListEnabled extends _$DailyListEnabled {
  @override
  bool build() => ref.watch(bootstrapProvider).dailyList;

  Future<void> set({required bool enabled}) async {
    state = enabled;
    await ref.read(kvStoreProvider).set(KvKeys.dailyList, '$enabled');
  }
}

/// When the daily list arrives: minutes after local midnight.
@Riverpod(keepAlive: true)
class DailyListMinutes extends _$DailyListMinutes {
  @override
  int build() => ref.watch(bootstrapProvider).dailyListMinutes;

  Future<void> set(int minutes) async {
    state = minutes;
    await ref.read(kvStoreProvider).set(KvKeys.dailyListMinutes, '$minutes');
  }
}
