import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/auth/ui/auth_guard.dart';
import 'package:nemo/router.dart';

String? go(
  String location, {
  bool required = true,
  bool restored = true,
  bool connected = false,
}) => AuthGuard.redirect(
  required: required,
  restored: restored,
  connected: connected,
  location: Uri.parse(location),
);

void main() {
  test('where an account is optional nothing is redirected', () {
    expect(go(Routes.today, required: false), isNull);
    expect(go(Routes.settings, required: false, restored: false), isNull);
  });

  test('a cold start waits on the splash rather than flashing a form', () {
    expect(go(Routes.today, restored: false), '/starting?from=%2Ftoday');
    expect(go(Routes.starting, restored: false), isNull);
  });

  test('without a session every address goes to sign-in', () {
    expect(go(Routes.today), '/sign-in?from=%2Ftoday');
    expect(go('/lists/abc'), '/sign-in?from=%2Flists%2Fabc');
    expect(go(Routes.signIn), isNull);
  });

  test('signing in lands where the session was headed', () {
    expect(go('/sign-in?from=%2Flists%2Fabc', connected: true), '/lists/abc');
    expect(go('/starting?from=%2Fsearch', connected: true), '/search');
    expect(go(Routes.signIn, connected: true), Routes.today);
  });

  test('a signed-in app is left alone', () {
    expect(go(Routes.today, connected: true), isNull);
    expect(go('/tasks/xyz', connected: true), isNull);
  });

  test('the gate never sends anyone back to the gate', () {
    // Where a request for the sign-in screen was itself carried through
    // the splash, "back where you came from" is not an answer.
    expect(go('/starting?from=%2Fsign-in', connected: true), Routes.today);
    expect(go('/sign-in?from=%2Fstarting', connected: true), Routes.today);
    expect(
      go('/sign-in?from=%2Ftoday', restored: false),
      '/starting?from=%2Ftoday',
    );
  });
}
