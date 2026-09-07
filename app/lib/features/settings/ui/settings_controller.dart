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
