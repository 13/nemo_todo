import 'package:nemo_server/nemo_server.dart';
import 'package:test/test.dart';

void main() {
  late ServerDatabase db;
  late DateTime now;

  AuthService service({bool? allowSignup}) => AuthService(
    db,
    allowSignup: allowSignup,
    now: () => now,
    bcryptRounds: 4,
  );

  setUp(() {
    db = ServerDatabase.memory();
    now = DateTime.fromMillisecondsSinceEpoch(1700000000000);
  });
  tearDown(() => db.close());

  test('auto policy: first signup open, second closed', () async {
    final auth = service();
    expect(await auth.signupOpen, isTrue);
    final first = await auth.signup('Ben', 'password123');
    expect(first.user.username, 'ben');
    expect(first.token, hasLength(43));
    expect(await auth.signupOpen, isFalse);
    expect(
      () => auth.signup('other', 'password123'),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'signup_disabled'),
      ),
    );
  });

  test('explicit policy allows more accounts and rejects duplicates', () async {
    final auth = service(allowSignup: true);
    await auth.signup('ben', 'password123');
    await auth.signup('anna', 'password123');
    expect(
      () => auth.signup('ben', 'password123'),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 409)),
    );
  });

  test('validates username and password', () async {
    final auth = service(allowSignup: true);
    expect(
      () => auth.signup('ab', 'password123'),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'invalid_username'),
      ),
    );
    expect(
      () => auth.signup('Bad Name', 'password123'),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'invalid_username'),
      ),
    );
    expect(
      () => auth.signup('ben', 'short'),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'weak_password'),
      ),
    );
  });

  test('login checks the password', () async {
    final auth = service(allowSignup: true);
    await auth.signup('ben', 'password123');
    final r = await auth.login('BEN', 'password123');
    expect(r.user.username, 'ben');
    expect(
      () => auth.login('ben', 'wrong-password'),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
    );
    expect(
      () => auth.login('nobody', 'password123'),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
    );
  });

  test('authenticate, sliding expiry, expiry and logout', () async {
    final auth = service(allowSignup: true);
    final r = await auth.signup('ben', 'password123');
    expect((await auth.authenticate(r.token))?.username, 'ben');
    expect(await auth.authenticate('nope'), isNull);

    now = now.add(const Duration(days: 20));
    expect((await auth.authenticate(r.token))?.username, 'ben');
    now = now.add(const Duration(days: 20));
    expect(
      (await auth.authenticate(r.token))?.username,
      'ben',
      reason: 'extended',
    );

    now = now.add(const Duration(days: 31));
    expect(await auth.authenticate(r.token), isNull, reason: 'expired');

    final again = await auth.login('ben', 'password123');
    await auth.logout(again.token);
    expect(await auth.authenticate(again.token), isNull);
  });

  test('resetPassword signs out everywhere', () async {
    final auth = service(allowSignup: true);
    final r = await auth.signup('ben', 'password123');
    await auth.resetPassword('ben', 'new-password-1');
    expect(await auth.authenticate(r.token), isNull);
    expect((await auth.login('ben', 'new-password-1')).user.username, 'ben');
    expect(
      () => auth.resetPassword('nobody', 'new-password-1'),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 404)),
    );
  });
}
