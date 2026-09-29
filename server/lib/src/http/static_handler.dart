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
/// A file with a `.br` or `.gz` sibling (written at build time by
/// `tool/compress_web.sh`) is sent compressed to a browser that accepts
/// that encoding, brotli first. The engine and the compiled app are about
/// 11 MB as built, under 4 MB gzipped and under 3 MB as brotli, and
/// nothing appears until both have arrived. Browsers only ask for brotli
/// over HTTPS, so gzip stays for a server reached over plain HTTP.
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
    // The compressed copies built for this file, most preferred first.
    final copies = [
      if (path.isNotEmpty)
        for (final (coding, suffix) in _encodings)
          (coding: coding, file: File('$webDir/$path$suffix')),
    ].where((c) => c.file.existsSync()).toList();
    final accept = request.headers['accept-encoding'];
    final chosen = copies
        .where((c) => acceptsEncoding(accept, c.coding))
        .firstOrNull;
    final compressed = chosen?.file;
    final headers = {
      ...noCache,
      if (copies.isNotEmpty) 'vary': 'accept-encoding',
    };

    // shelf_static answers If-Modified-Since itself, but compares a date
    // that still carries microseconds, so on Linux every file looks newer
    // than the second-resolution date the browser sent back and is sent
    // again in full. The comparison is made here instead, until
    // https://github.com/dart-lang/shelf/issues/532 is fixed.
    final served = compressed ?? _fileFor(webDir, path, index);
    if (served != null && _unchanged(request, served)) {
      return Response.notModified(headers: headers);
    }

    if (compressed != null) {
      final suffix = compressed.path.substring(compressed.path.length - 3);
      final response = await files(
        Request(
          request.method,
          request.requestedUri.replace(
            path: '${request.requestedUri.path}$suffix',
          ),
          headers: request.headers,
          handlerPath: request.handlerPath,
          url: request.url.replace(path: '$path$suffix'),
          context: request.context,
        ),
      );
      return response.change(
        headers: {
          ...headers,
          if (response.statusCode != 304) ...{
            'content-encoding': chosen!.coding,
            'content-type': lookupMimeType(path) ?? 'application/octet-stream',
          },
        },
      );
    }
    final response = await files(request);
    if (response.statusCode != 404) return response.change(headers: headers);
    if (served != index || !index.existsSync()) return response;
    return Response.ok(
      index.openRead(),
      headers: {
        'content-type': 'text/html; charset=utf-8',
        'last-modified': HttpDate.format(index.statSync().modified),
        ...noCache,
      },
    );
  };
}

/// The compressed copies the server looks for, most preferred first.
const _encodings = [('br', '.br'), ('gzip', '.gz')];

/// The file a request for [path] is answered with: the file itself, or
/// `index.html` for the root and for app routes (paths without an
/// extension), or null for a file that is not there.
File? _fileFor(String webDir, String path, File index) {
  if (path.isEmpty) return index;
  final file = File('$webDir/$path');
  if (file.existsSync()) return file;
  final last = path.split('/').last;
  return last.contains('.') ? null : index;
}

/// Whether [file] is unchanged since the request's If-Modified-Since, at
/// the one-second resolution HTTP dates have.
bool _unchanged(Request request, File file) {
  final since = request.ifModifiedSince;
  if (since == null || !file.existsSync()) return false;
  final modified = file.statSync().modified.millisecondsSinceEpoch ~/ 1000;
  return modified <= since.millisecondsSinceEpoch ~/ 1000;
}

/// Whether an `accept-encoding` header allows [coding], which it does
/// unless it leaves it out or gives it a quality of zero.
bool acceptsEncoding(String? acceptEncoding, String coding) {
  if (acceptEncoding == null) return false;
  for (final entry in acceptEncoding.split(',')) {
    final parts = entry.split(';').map((p) => p.trim()).toList();
    if (parts.first != coding && parts.first != '*') continue;
    final q = parts
        .skip(1)
        .where((p) => p.startsWith('q='))
        .map((p) => double.tryParse(p.substring(2)))
        .firstOrNull;
    return q == null || q > 0;
  }
  return false;
}
