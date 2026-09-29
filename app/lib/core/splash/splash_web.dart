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

/// Leaves the app's theme -- `light`, `dark` or `system` -- where the
/// server can read it when it next serves the page, so the loading screen
/// paints in the app's theme rather than the device's.
void rememberTheme(String mode) => _remember('nemo-theme', mode);

/// Leaves the app's style -- `nemo`, `macos` or `material` -- beside its
/// theme, for the same reason: the loading screen paints in the style's
/// colours rather than flashing nemo's teal before a different app.
void rememberStyle(String style) => _remember('nemo-style', style);

void _remember(String name, String value) {
  web.document.cookie = '$name=$value; path=/; max-age=31536000; samesite=lax';
}
