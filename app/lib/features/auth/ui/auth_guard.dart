import 'package:nemo/router.dart';

/// Keeps the app behind the sign-in screen where an account is required.
///
/// The web app is served by the server it syncs with, and shows nothing
/// until it knows whose tasks to show. That is a routing rule rather than a
/// screen: every address, typed or bookmarked, goes through it.
///
/// Where an account is optional -- the Android app -- this lets everything
/// through and the app works as it always has, offline and unsigned-in.
abstract final class AuthGuard {
  /// Where a request for [location] should go instead, or null to let it
  /// through.
  static String? redirect({
    required bool required,
    required bool restored,
    required bool connected,
    required Uri location,
  }) {
    if (!required) return null;
    final path = location.path;
    // A cold start does not know yet whether there is a session; sending
    // it to the sign-in screen would flash a form at someone who is
    // already signed in. It waits on the splash instead.
    if (!restored) {
      return path == Routes.starting ? null : _gate(Routes.starting, location);
    }
    if (!connected) {
      return path == Routes.signIn ? null : _gate(Routes.signIn, location);
    }
    if (path != Routes.starting && path != Routes.signIn) return null;
    return _wanted(location) ?? Routes.today;
  }

  static bool _isGate(String path) =>
      path == Routes.starting || path == Routes.signIn;

  /// The address that was asked for before the gate got in the way.
  static String? _wanted(Uri location) {
    final from = location.queryParameters['from'];
    if (from == null || from.isEmpty) return null;
    return _isGate(Uri.parse(from).path) ? null : from;
  }

  /// Sends the request to [gate], carrying where it was going so signing
  /// in lands there rather than on Today.
  static String _gate(String gate, Uri location) {
    final from = _isGate(location.path)
        ? _wanted(location)
        : location.toString();
    return from == null ? gate : '$gate?from=${Uri.encodeQueryComponent(from)}';
  }
}
