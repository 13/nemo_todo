/// The loading screen `web/index.html` shows while the engine, the app and
/// its database start, and the theme it paints in. Only the web has one;
/// elsewhere this does nothing.
library;

export 'splash_stub.dart' if (dart.library.js_interop) 'splash_web.dart';
