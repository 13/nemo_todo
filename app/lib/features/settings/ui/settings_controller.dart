import 'package:flutter/material.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_controller.g.dart';

/// Theme preference, persisted in the key-value store.
@Riverpod(keepAlive: true)
class ThemeModeController extends _$ThemeModeController {
  @override
  ThemeMode build() => ref.watch(bootstrapProvider).themeMode;

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(kvStoreProvider).set(KvKeys.themeMode, mode.name);
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
