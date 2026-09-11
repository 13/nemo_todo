import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/features/auth/data/auth_storage.dart';
import 'package:nemo/features/auth/data/certificate_trust.dart';
import 'package:nemo/features/auth/data/certificate_trust_adapter.dart';
import 'package:nemo/features/sync/data/sync_client.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_controller.g.dart';

/// The connection to a server, if any. The token itself is never held here.
class AuthState {
  const AuthState({
    this.serverUrl,
    this.username,
    this.token,
    this.restored = false,
  });

  final String? serverUrl;
  final String? username;
  final String? token;

  /// Whether the stored session has been looked for yet. Until it has,
  /// "not connected" only means "not known", which is the difference
  /// between showing the sign-in screen and waiting a moment longer.
  final bool restored;

  bool get connected => serverUrl != null && username != null && token != null;

  /// Signed out by the server rather than by the user: the address is still
  /// here, the session is not.
  bool get sessionLost => !connected && serverUrl != null;
}

/// Certificates the user has chosen to trust for a host.
final certificateTrustProvider = Provider<CertificateTrust>(
  (ref) => CertificateTrust(
    ref.watch(kvStoreProvider),
    trusted: CertificateTrust.decode(
      ref.watch(bootstrapProvider).trustedCertificates,
    ),
  ),
);

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      // Errors are mapped by SyncClient, so let every status through.
      validateStatus: (status) => status != null && status < 400,
    ),
  );
  applyCertificateTrust(dio, ref.watch(certificateTrustProvider));
  return dio;
});

final authStorageProvider = Provider<AuthStorage>((_) => SecureAuthStorage());

/// Exchanges credentials for a session. Replaced in tests.
typedef Authenticate = Future<({String token, String username})> Function(
  Dio dio, {
  required String baseUrl,
  required String username,
  required String password,
  required bool signUp,
});

final authenticateProvider = Provider<Authenticate>(
  (_) => SyncClient.authenticate,
);

/// Signing in, signing up and signing out.
///
/// Signing in never destroys local data: the rows already on the device are
/// queued for upload, so a fresh account adopts them and an existing account
/// merges them by last-write-wins.
@Riverpod(keepAlive: true)
class AuthController extends _$AuthController {
  @override
  AuthState build() {
    final boot = ref.watch(bootstrapProvider);
    return AuthState(serverUrl: boot.serverUrl, username: boot.username);
  }

  /// Reads the stored token so an existing session survives a restart.
  Future<void> restore() async {
    final token = state.serverUrl == null || state.username == null
        ? null
        : await ref.read(authStorageProvider).readToken();
    state = AuthState(
      serverUrl: state.serverUrl,
      username: state.username,
      token: token,
      restored: true,
    );
  }

  Future<void> signIn({
    required String serverUrl,
    required String username,
    required String password,
    bool signUp = false,
  }) async {
    final url = SyncClient.normaliseBaseUrl(serverUrl);
    final session = await ref.read(authenticateProvider)(
      ref.read(dioProvider),
      baseUrl: url,
      username: username.trim().toLowerCase(),
      password: password,
      signUp: signUp,
    );
    final kv = ref.read(kvStoreProvider);
    await ref.read(authStorageProvider).writeToken(session.token);
    await kv.set(KvKeys.serverUrl, url);
    await kv.set(KvKeys.username, session.username);
    // A new session starts from the beginning of the server's change log.
    await kv.set(KvKeys.cursor, '0');
    state = AuthState(
      serverUrl: url,
      username: session.username,
      token: session.token,
      restored: true,
    );
  }

  /// Forgets the session but keeps every task on the device.
  Future<void> signOut() async {
    final kv = ref.read(kvStoreProvider);
    await ref.read(authStorageProvider).writeToken(null);
    await kv.set(KvKeys.serverUrl, null);
    await kv.set(KvKeys.username, null);
    await kv.set(KvKeys.cursor, null);
    await kv.set(KvKeys.lastSyncAt, null);
    state = const AuthState(restored: true);
  }

  /// The server rejected our token; keep the address for a quick re-login.
  Future<void> sessionExpired() async {
    await ref.read(authStorageProvider).writeToken(null);
    state = AuthState(
      serverUrl: state.serverUrl,
      username: state.username,
      restored: true,
    );
  }
}
