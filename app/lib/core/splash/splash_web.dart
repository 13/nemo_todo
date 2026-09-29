import 'package:web/web.dart' as web;

/// Fades out the page's loading screen and then takes it out of the page.
///
/// Called once the app has drawn its first frame, which covers the screen
/// anyway; removing it stops its spinner animating out of sight.
void removeSplash() {
  final splash = web.document.getElementById('splash');
  if (splash == null) return;
  splash.classList.add('done');
  Future<void>.delayed(
    const Duration(milliseconds: 300),
    // An interop member cannot be torn off.
    // ignore: unnecessary_lambdas
    () => splash.remove(),
  );
}
