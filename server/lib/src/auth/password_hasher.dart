import 'dart:isolate';

import 'package:bcrypt/bcrypt.dart';

typedef PasswordHasher = Future<String> Function(String password, int rounds);
typedef PasswordVerifier = Future<bool> Function(String password, String hash);

/// bcrypt is deliberately slow, and this server runs on a single thread, so
/// hashing on it stalls every sync request and event stream for as long as
/// it takes. These hand the work to a worker isolate instead.
///
/// They are top-level functions on purpose. The same call written inside
/// `AuthService` would close over `this`, and sending that to an isolate
/// drags the database and its stream controllers along, which fails at run
/// time rather than compile time.
Future<String> hashPassword(String password, int rounds) => Isolate.run(
  () => BCrypt.hashpw(password, BCrypt.gensalt(logRounds: rounds)),
);

Future<bool> verifyPassword(String password, String hash) =>
    Isolate.run(() => BCrypt.checkpw(password, hash));
