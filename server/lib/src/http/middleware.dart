import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:nemo_server/src/api_exception.dart';
import 'package:nemo_server/src/auth/auth_service.dart';
import 'package:nemo_server/src/auth/rate_limiter.dart';
import 'package:shelf/shelf.dart';

final _log = Logger('nemo.http');

const _jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

Response jsonResponse(Object body, {int status = 200}) =>
    Response(status, body: jsonEncode(body), headers: _jsonHeaders);

Response errorResponse(int status, String code) =>
    jsonResponse({'error': code}, status: status);

/// Reads a JSON object body; anything else is a 400.
Future<Map<String, dynamic>> readJson(Request request) async {
  final Object? decoded;
  try {
    decoded = jsonDecode(await request.readAsString());
  } on FormatException {
    throw const ApiException(400, 'bad_json');
  }
  if (decoded is! Map<String, dynamic>) {
    throw const ApiException(400, 'bad_json');
  }
  return decoded;
}

/// Turns [ApiException]s into JSON errors and anything else into a 500.
Middleware jsonErrors() =>
    (inner) => (request) async {
      try {
        return await inner(request);
      } on ApiException catch (e) {
        return errorResponse(e.status, e.code);
      } on HijackException {
        rethrow;
      } on Object catch (e, s) {
        _log.severe(
          'unhandled error for ${request.method} ${request.url}',
          e,
          s,
        );
        return errorResponse(500, 'internal');
      }
    };

Middleware requestLogging() =>
    (inner) => (request) async {
      final started = DateTime.now();
      final response = await inner(request);
      final ms = DateTime.now().difference(started).inMilliseconds;
      _log.info(
        '${request.method} /${request.url.path} ${response.statusCode} ${ms}ms',
      );
      return response;
    };

const contentSecurityPolicy =
    "default-src 'self'; script-src 'self' 'wasm-unsafe-eval'; "
    "style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; "
    "font-src 'self' data:; connect-src 'self'; worker-src 'self' blob:; "
    "frame-ancestors 'none'; base-uri 'self'";

Middleware securityHeaders() =>
    (inner) => (request) async {
      final response = await inner(request);
      return response.change(
        headers: {
          'x-content-type-options': 'nosniff',
          'x-frame-options': 'DENY',
          'referrer-policy': 'same-origin',
          'content-security-policy': contentSecurityPolicy,
          ...response.headersAll,
        },
      );
    };

/// CORS for the listed origins only (development builds served from
/// another origin). No-op when [origins] is empty.
Middleware cors(List<String> origins) =>
    (inner) => (request) async {
      final origin = request.headers['origin'];
      if (origin == null || !origins.contains(origin)) {
        return request.method == 'OPTIONS' && origin != null
            ? Response(403)
            : await inner(request);
      }
      final headers = {
        'access-control-allow-origin': origin,
        'access-control-allow-methods': 'GET, POST, DELETE, OPTIONS',
        'access-control-allow-headers': 'authorization, content-type',
        'access-control-max-age': '600',
        'vary': 'origin',
      };
      if (request.method == 'OPTIONS') return Response(204, headers: headers);
      final response = await inner(request);
      return response.change(headers: headers);
    };

String clientIp(Request request) {
  final forwarded = request.headers['x-forwarded-for'];
  if (forwarded != null && forwarded.isNotEmpty) {
    return forwarded.split(',').first.trim();
  }
  final info = request.context['shelf.io.connection_info'];
  if (info is HttpConnectionInfo) return info.remoteAddress.address;
  return 'unknown';
}

Middleware rateLimit(RateLimiter limiter) =>
    (inner) => (request) async {
      if (!limiter.allow(clientIp(request))) {
        return errorResponse(429, 'too_many_requests');
      }
      return await inner(request);
    };

String? bearerToken(Request request) {
  final header = request.headers['authorization'];
  if (header == null) return null;
  const prefix = 'Bearer ';
  if (!header.startsWith(prefix)) return null;
  final token = header.substring(prefix.length).trim();
  return token.isEmpty ? null : token;
}

/// Requires a valid session; the user lands in the request context.
Middleware requireAuth(AuthService auth, {bool allowQueryToken = false}) =>
    (inner) => (request) async {
      final token =
          bearerToken(request) ??
          (allowQueryToken ? request.url.queryParameters['token'] : null);
      if (token == null) return errorResponse(401, 'unauthorized');
      final user = await auth.authenticate(token);
      if (user == null) return errorResponse(401, 'unauthorized');
      return await inner(
        request.change(context: {'nemo.user': user, 'nemo.token': token}),
      );
    };

extension AuthenticatedRequest on Request {
  AuthUser get user => context['nemo.user']! as AuthUser;
  String get token => context['nemo.token']! as String;
}
