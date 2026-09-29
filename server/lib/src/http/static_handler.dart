import 'dart:io';

import 'package:mime/mime.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_static/shelf_static.dart';

/// Serves the built Flutter web app. Paths without a file extension fall
/// back to `index.html` so deep links into the app work.
///
/// Every file is sent `no-cache`: none of Flutter's file names carry a
/// hash, so a browser that reused a cached `main.dart.js` or canvaskit
/// without asking would pair it with a newer `flutter_bootstrap.js` after a
/// deploy. Asking costs a 304 per file; a mismatched engine costs a blank
/// page.
///
/// A file with a `.gz` sibling (written at build time by
/// `tool/compress_web.sh`) is sent compressed to a browser that accepts
/// gzip. The engine and the compiled app are about 11 MB as built and
/// under 4 MB compressed, and nothing appears until both have arrived.
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
    final compressed = File('$webDir/$path.gz');
    if (path.isNotEmpty && compressed.existsSync()) {
      const vary = {'vary': 'accept-encoding', ...noCache};
      if (!acceptsGzip(request.headers['accept-encoding'])) {
        final response = await files(request);
        return response.change(headers: vary);
      }
      final response = await files(
        Request(
          request.method,
          request.requestedUri.replace(path: '${request.requestedUri.path}.gz'),
          headers: request.headers,
          handlerPath: request.handlerPath,
          url: request.url.replace(path: '$path.gz'),
          context: request.context,
        ),
      );
      return response.change(
        headers: {
          ...vary,
          if (response.statusCode != 304) ...{
            'content-encoding': 'gzip',
            'content-type': lookupMimeType(path) ?? 'application/octet-stream',
          },
        },
      );
    }
    final response = await files(request);
    if (response.statusCode != 404) return response.change(headers: noCache);
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

/// Whether an `accept-encoding` header allows gzip, which it does unless
/// it leaves gzip out or gives it a quality of zero.
bool acceptsGzip(String? acceptEncoding) {
  if (acceptEncoding == null) return false;
  for (final entry in acceptEncoding.split(',')) {
    final parts = entry.split(';').map((p) => p.trim()).toList();
    if (parts.first != 'gzip' && parts.first != '*') continue;
    final q = parts
        .skip(1)
        .where((p) => p.startsWith('q='))
        .map((p) => double.tryParse(p.substring(2)))
        .firstOrNull;
    return q == null || q > 0;
  }
  return false;
}
