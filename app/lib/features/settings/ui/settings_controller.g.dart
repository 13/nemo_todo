// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Theme preference, persisted in the key-value store.

@ProviderFor(ThemeModeController)
final themeModeControllerProvider = ThemeModeControllerProvider._();

/// Theme preference, persisted in the key-value store.
final class ThemeModeControllerProvider
    extends $NotifierProvider<ThemeModeController, ThemeMode> {
  /// Theme preference, persisted in the key-value store.
  ThemeModeControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeModeControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themeModeControllerHash();

  @$internal
  @override
  ThemeModeController create() => ThemeModeController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ThemeMode value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ThemeMode>(value),
    );
  }
}

String _$themeModeControllerHash() =>
    r'adfdcb58e346afe7c6f58a834acd304150bc50bb';

/// Theme preference, persisted in the key-value store.

abstract class _$ThemeModeController extends $Notifier<ThemeMode> {
  ThemeMode build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ThemeMode, ThemeMode>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ThemeMode, ThemeMode>,
              ThemeMode,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Confetti, animations and haptics on completing a task.

@ProviderFor(CelebrationsEnabled)
final celebrationsEnabledProvider = CelebrationsEnabledProvider._();

/// Confetti, animations and haptics on completing a task.
final class CelebrationsEnabledProvider
    extends $NotifierProvider<CelebrationsEnabled, bool> {
  /// Confetti, animations and haptics on completing a task.
  CelebrationsEnabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'celebrationsEnabledProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$celebrationsEnabledHash();

  @$internal
  @override
  CelebrationsEnabled create() => CelebrationsEnabled();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$celebrationsEnabledHash() =>
    r'd19ca6f6dbf0dd2c00db41bb752b63a9253fd847';

/// Confetti, animations and haptics on completing a task.

abstract class _$CelebrationsEnabled extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// A sound for a cleared day or an unlocked achievement.

@ProviderFor(CelebrationSoundEnabled)
final celebrationSoundEnabledProvider = CelebrationSoundEnabledProvider._();

/// A sound for a cleared day or an unlocked achievement.
final class CelebrationSoundEnabledProvider
    extends $NotifierProvider<CelebrationSoundEnabled, bool> {
  /// A sound for a cleared day or an unlocked achievement.
  CelebrationSoundEnabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'celebrationSoundEnabledProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$celebrationSoundEnabledHash();

  @$internal
  @override
  CelebrationSoundEnabled create() => CelebrationSoundEnabled();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$celebrationSoundEnabledHash() =>
    r'0d6e82266770e74add639e95c8d42d9d19df430e';

/// A sound for a cleared day or an unlocked achievement.

abstract class _$CelebrationSoundEnabled extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Achievements, their unlock banners and their Settings tile.

@ProviderFor(AchievementsEnabled)
final achievementsEnabledProvider = AchievementsEnabledProvider._();

/// Achievements, their unlock banners and their Settings tile.
final class AchievementsEnabledProvider
    extends $NotifierProvider<AchievementsEnabled, bool> {
  /// Achievements, their unlock banners and their Settings tile.
  AchievementsEnabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'achievementsEnabledProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$achievementsEnabledHash();

  @$internal
  @override
  AchievementsEnabled create() => AchievementsEnabled();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$achievementsEnabledHash() =>
    r'14e77bcebe2b4d0b6c1b92b08214fe6140969fc7';

/// Achievements, their unlock banners and their Settings tile.

abstract class _$AchievementsEnabled extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// Which currency the amounts on a task are written in.

@ProviderFor(CurrencyCode)
final currencyCodeProvider = CurrencyCodeProvider._();

/// Which currency the amounts on a task are written in.
final class CurrencyCodeProvider
    extends $NotifierProvider<CurrencyCode, String> {
  /// Which currency the amounts on a task are written in.
  CurrencyCodeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currencyCodeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currencyCodeHash();

  @$internal
  @override
  CurrencyCode create() => CurrencyCode();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$currencyCodeHash() => r'91fef8e4c0f3acc84071bc1e73457015b9081502';

/// Which currency the amounts on a task are written in.

abstract class _$CurrencyCode extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
