import 'dart:convert';
import 'dart:math';

import 'package:bcrypt/bcrypt.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:nemo_server/src/api_exception.dart';
import 'package:nemo_server/src/db/server_database.dart';
import 'package:uuid/uuid.dart';

class AuthUser {
  const AuthUser({required this.id, required this.username});

  final String id;
  final String username;
}

typedef AuthResult = ({AuthUser user, String token});

/// SHA-256 hex of a session token; only hashes are stored.
String hashToken(String token) => sha256.convert(utf8.encode(token)).toString();

/// Accounts and sessions.
class AuthService {
  AuthService(
    this._db, {
    this.allowSignup,
    DateTime Function()? now,
    Random? random,
    this.bcryptRounds = 12,
    this.sessionLifetime = const Duration(days: 30),
  }) : _now = now ?? DateTime.now,
       _random = random ?? Random.secure();

  static final _usernamePattern = RegExp(r'^[a-z0-9_.-]{3,32}$');
  static const minPasswordLength = 8;

  final ServerDatabase _db;

  /// Explicit policy; `null` means open until the first account exists.
  final bool? allowSignup;
  final DateTime Function() _now;
  final Random _random;
  final int bcryptRounds;
  final Duration sessionLifetime;

  /// Explicit setting, else open only until the first account exists.
  Future<bool> get signupOpen async {
    if (allowSignup != null) return allowSignup!;
    final row = await _db
        .customSelect('select count(*) as c from users')
        .getSingle();
    return row.read<int>('c') == 0;
  }

  Future<AuthResult> signup(String username, String password) async {
    final name = _normalise(username);
    if (!_usernamePattern.hasMatch(name)) {
      throw const ApiException(400, 'invalid_username');
    }
    _checkPassword(password);
    if (!await signupOpen) throw const ApiException(403, 'signup_disabled');
    if (await _userByName(name) != null) {
      throw const ApiException(409, 'username_taken');
    }
    final user = User(
      id: const Uuid().v4(),
      username: name,
      passwordHash: BCrypt.hashpw(
        password,
        BCrypt.gensalt(logRounds: bcryptRounds),
      ),
      createdAt: _now().millisecondsSinceEpoch,
    );
    await _db.into(_db.users).insert(user);
    return await _createSession(user);
  }

  Future<AuthResult> login(String username, String password) async {
    final user = await _userByName(_normalise(username));
    if (user == null || !BCrypt.checkpw(password, user.passwordHash)) {
      throw const ApiException(401, 'invalid_credentials');
    }
    return await _createSession(user);
  }

  /// The user behind [token], or null. Extends the session once more than
  /// half of its lifetime has passed, so an active session never expires.
  Future<AuthUser?> authenticate(String token) async {
    final hash = hashToken(token);
    final session = await (_db.select(
      _db.sessions,
    )..where((t) => t.tokenHash.equals(hash))).getSingleOrNull();
    if (session == null) return null;
    final now = _now().millisecondsSinceEpoch;
    if (session.expiresAt <= now) {
      await _deleteSession(hash);
      return null;
    }
    if (session.expiresAt - now < sessionLifetime.inMilliseconds ~/ 2) {
      await (_db.update(
        _db.sessions,
      )..where((t) => t.tokenHash.equals(hash))).write(
        SessionsCompanion(
          expiresAt: Value(now + sessionLifetime.inMilliseconds),
        ),
      );
    }
    final user = await (_db.select(
      _db.users,
    )..where((t) => t.id.equals(session.userId))).getSingleOrNull();
    if (user == null) return null;
    return AuthUser(id: user.id, username: user.username);
  }

  Future<void> logout(String token) => _deleteSession(hashToken(token));

  /// Sets a new password and signs the user out everywhere.
  Future<void> resetPassword(String username, String newPassword) async {
    _checkPassword(newPassword);
    final user = await _userByName(_normalise(username));
    if (user == null) throw const ApiException(404, 'unknown_user');
    await (_db.update(_db.users)..where((t) => t.id.equals(user.id))).write(
      UsersCompanion(
        passwordHash: Value(
          BCrypt.hashpw(newPassword, BCrypt.gensalt(logRounds: bcryptRounds)),
        ),
      ),
    );
    await (_db.delete(
      _db.sessions,
    )..where((t) => t.userId.equals(user.id))).go();
  }

  String _normalise(String username) => username.trim().toLowerCase();

  void _checkPassword(String password) {
    if (password.length < minPasswordLength) {
      throw const ApiException(400, 'weak_password');
    }
  }

  Future<User?> _userByName(String name) => (_db.select(
    _db.users,
  )..where((t) => t.username.equals(name))).getSingleOrNull();

  Future<void> _deleteSession(String hash) =>
      (_db.delete(_db.sessions)..where((t) => t.tokenHash.equals(hash))).go();

  Future<AuthResult> _createSession(User user) async {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    final token = base64UrlEncode(bytes).replaceAll('=', '');
    final now = _now().millisecondsSinceEpoch;
    await _db
        .into(_db.sessions)
        .insert(
          SessionsCompanion.insert(
            tokenHash: hashToken(token),
            userId: user.id,
            expiresAt: now + sessionLifetime.inMilliseconds,
            createdAt: now,
          ),
        );
    return (user: AuthUser(id: user.id, username: user.username), token: token);
  }
}
