import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'package:mime/mime.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_static/shelf_static.dart';

/// Serves the built Flutter web app. Paths without a file extension fall
/// back to `index.html` so deep links into the app work.
///
/// None of Flutter's file names carry a hash, so on their own they could
/// only be sent `no-cache`: a browser reusing a cached `main.dart.js`
/// without asking would pair it with a newer `flutter_bootstrap.js` after a
/// deploy. But asking costs a round trip per file, and the files load one
/// after another -- page, bootstrap, app and engine, fonts, database -- so
/// a repeat visit spent more time waiting on 304s than starting the app.
///
/// So each build gets a path of its own. The page is served with its
/// `<base href>` pointing at `v/<build>/`, which every file it loads is
/// relative to, and anything under the current build's path is cached
/// for good: a new build is a new path. Only the page itself is asked
/// about again. The app routes by the URL's fragment, so the base path
/// changes nothing it sees. The manifest keeps its one address, because
/// an installed app is known by it. Paths of an older build, which a tab
/// left open may still ask for, and paths without a build are served
/// `no-cache`.
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
  final files = createStaticHandler(webDir);
  final index = File('$webDir/index.html');
  final build = _BuildId(webDir, index);
  const noCache = {'cache-control': 'no-cache'};
  const forGood = {'cache-control': 'public, max-age=31536000, immutable'};

  return (request) async {
    var path = request.url.path;
    var caching = noCache;
    if (_underBuild.firstMatch(path) case final m?) {
      path = m[2]!;
      if (m[1] == build.current) caching = forGood;
    }

    final page = _fileFor(webDir, path, index);
    if (page?.path == index.path) {
      return _page(request, index, build.current, noCache);
    }

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
    final headers = {
      ...caching,
      if (copies.isNotEmpty) 'vary': 'accept-encoding',
    };

    // shelf_static answers If-Modified-Since itself, but compares a date
    // that still carries microseconds, so on Linux every file looks newer
    // than the second-resolution date the browser sent back and is sent
    // again in full. The comparison is made here instead, until
    // https://github.com/dart-lang/shelf/issues/532 is fixed.
    final served = chosen?.file ?? page;
    if (served != null && _unchanged(request, served)) {
      return Response.notModified(headers: headers);
    }

    final suffix = switch (chosen) {
      final c? => c.file.path.substring(c.file.path.length - 3),
      null => '',
    };
    final response = await files(_at(request, '$path$suffix'));
    return response.change(
      headers: {
        ...headers,
        if (chosen != null && response.statusCode == 200) ...{
          'content-encoding': chosen.coding,
          'content-type': lookupMimeType(path) ?? 'application/octet-stream',
        },
      },
    );
  };
}

/// A path under a build's own prefix: `v/<build>/<file>`.
final _underBuild = RegExp(r'^v/([0-9a-f]{12})/(.*)$');

/// The page, with everything it loads pointed at [build]'s own path, and
/// the manifest left where it is.
Response _page(
  Request request,
  File index,
  String build,
  Map<String, String> headers,
) {
  if (!index.existsSync()) return Response.notFound('not found');
  if (_unchanged(request, index)) {
    return Response.notModified(headers: headers);
  }
  var base = '/';
  final html = index
      .readAsStringSync()
      .replaceFirstMapped(RegExp('<base href="([^"]*)">'), (m) {
        base = m[1]!;
        return '<base href="${base}v/$build/">';
      })
      .replaceFirstMapped(
        RegExp('<link rel="manifest" href="(?![a-z]+:|/)([^"]*)">'),
        (m) => '<link rel="manifest" href="$base${m[1]}">',
      );
  return Response.ok(
    request.method == 'HEAD' ? null : html,
    headers: {
      'content-type': 'text/html; charset=utf-8',
      'last-modified': HttpDate.format(index.statSync().modified),
      ...headers,
    },
  );
}

/// [request], asking for [path] instead.
Request _at(Request request, String path) => Request(
  request.method,
  request.requestedUri.replace(path: '${request.handlerPath}$path'),
  headers: request.headers,
  handlerPath: request.handlerPath,
  url: request.url.replace(path: path),
  context: request.context,
);

/// One file's path, size and date, as a line of what names a build.
String _describe(File file, String webDir) {
  final stat = file.statSync();
  return '${file.path.substring(webDir.length)}\t${stat.size}\t'
      '${stat.modified.microsecondsSinceEpoch}';
}

/// Names the build in a web directory, from every file's path, size and
/// date. Worked out again whenever `index.html` changes, which every
/// `flutter build web` rewrites, so replacing a build under a running
/// server gives it a new path rather than new files under an old one.
class _BuildId {
  _BuildId(this.webDir, this.index);

  final String webDir;
  final File index;
  DateTime? _seen;
  String _id = '';

  String get current {
    final modified = index.existsSync() ? index.statSync().modified : null;
    if (modified != _seen) {
      _seen = modified;
      final entries = [
        for (final f in Directory(webDir).listSync(recursive: true))
          if (f is File) _describe(f, webDir),
      ]..sort();
      _id = sha256
          .convert(utf8.encode(entries.join('\n')))
          .toString()
          .substring(0, 12);
    }
    return _id;
  }
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
