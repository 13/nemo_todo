// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Signing in, signing up and signing out.
///
/// Signing in never destroys local data: the rows already on the device are
/// queued for upload, so a fresh account adopts them and an existing account
/// merges them by last-write-wins.

@ProviderFor(AuthController)
final authControllerProvider = AuthControllerProvider._();

/// Signing in, signing up and signing out.
///
/// Signing in never destroys local data: the rows already on the device are
/// queued for upload, so a fresh account adopts them and an existing account
/// merges them by last-write-wins.
final class AuthControllerProvider
    extends $NotifierProvider<AuthController, AuthState> {
  /// Signing in, signing up and signing out.
  ///
  /// Signing in never destroys local data: the rows already on the device are
  /// queued for upload, so a fresh account adopts them and an existing account
  /// merges them by last-write-wins.
  AuthControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authControllerHash();

  @$internal
  @override
  AuthController create() => AuthController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthState>(value),
    );
  }
}

String _$authControllerHash() => r'd39780f0b456cd67eadeabbde3230c270a570143';

/// Signing in, signing up and signing out.
///
/// Signing in never destroys local data: the rows already on the device are
/// queued for upload, so a fresh account adopts them and an existing account
/// merges them by last-write-wins.

abstract class _$AuthController extends $Notifier<AuthState> {
  AuthState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AuthState, AuthState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AuthState, AuthState>,
              AuthState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
