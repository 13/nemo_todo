import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf_static/shelf_static.dart';

/// Serves the built Flutter web app. Paths without a file extension fall
/// back to `index.html` so deep links into the app work; `index.html` and
/// the service worker are never cached so a deploy is picked up at once.
Handler webAppHandler(String webDir) {
  if (!Directory(webDir).existsSync()) {
    return (_) => Response.notFound(
      'web app not built',
      headers: const {'content-type': 'text/plain'},
    );
  }
  final files = createStaticHandler(webDir, defaultDocument: 'index.html');
  final index = File('$webDir/index.html');
  const noCache = {'cache-control': 'no-cache'};

  return (request) async {
    final path = request.url.path;
    final response = await files(request);
    if (response.statusCode != 404) {
      final volatile =
          path.isEmpty ||
          path.endsWith('index.html') ||
          path == 'flutter_service_worker.js' ||
          path == 'flutter_bootstrap.js' ||
          path == 'version.json';
      return volatile ? response.change(headers: noCache) : response;
    }
    final last = request.url.pathSegments.isEmpty
        ? ''
        : request.url.pathSegments.last;
    if (last.contains('.') || !index.existsSync()) return response;
    return Response.ok(
      index.openRead(),
      headers: const {'content-type': 'text/html; charset=utf-8', ...noCache},
    );
  };
}
