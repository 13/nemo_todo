import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the session token lives.
///
/// On Android this is the platform keystore. On the web there is no such
/// vault: the package falls back to browser storage, which is readable by
/// any script that manages to run on the page. That is stated in the
/// README rather than hidden here.
abstract interface class AuthStorage {
  Future<String?> readToken();
  Future<void> writeToken(String? token);
}

class SecureAuthStorage implements AuthStorage {
  SecureAuthStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'nemo_session_token';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readToken() => _storage.read(key: _key);

  @override
  Future<void> writeToken(String? token) => token == null
      ? _storage.delete(key: _key)
      : _storage.write(key: _key, value: token);
}

/// In-memory storage for tests and for platforms without a vault.
class MemoryAuthStorage implements AuthStorage {
  MemoryAuthStorage([this._token]);

  String? _token;

  @override
  Future<String?> readToken() async => _token;

  @override
  Future<void> writeToken(String? token) async => _token = token;
}
