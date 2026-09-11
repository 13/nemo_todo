import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:nemo_server/nemo_server.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

/// A real HTTP server over an in-memory database for handler tests.
class TestServer {
  TestServer._(this.db, this.hub, this.auth, this._server);

  final ServerDatabase db;
  final EventHub hub;
  final AuthService auth;
  final HttpServer _server;

  static Future<TestServer> start({
    bool? allowSignup = true,
    String? webDir,
    List<String> corsOrigins = const [],
    DateTime Function()? now,
    RateLimiter? limiter,
    String version = 'dev',
  }) async {
    final db = ServerDatabase.memory();
    final hub = EventHub(heartbeat: const Duration(milliseconds: 200));
    final auth = AuthService(
      db,
      allowSignup: allowSignup,
      now: now,
      bcryptRounds: 4,
    );
    final handler = createHandler(
      db: db,
      config: Config(
        webDir: webDir ?? '/nonexistent/web',
        allowSignup: allowSignup,
        corsOrigins: corsOrigins,
        version: version,
      ),
      auth: auth,
      hub: hub,
      now: now,
      limiter: limiter,
    );
    final server = await shelf_io.serve(
      handler,
      InternetAddress.loopbackIPv4,
      0,
    );
    return TestServer._(db, hub, auth, server);
  }

  Uri uri(String path) => Uri.parse('http://127.0.0.1:${_server.port}$path');

  Map<String, String> headers(String? token) => {
    'content-type': 'application/json',
    if (token != null) 'authorization': 'Bearer $token',
  };

  Future<http.Response> post(String path, Object body, {String? token}) =>
      http.post(uri(path), headers: headers(token), body: jsonEncode(body));

  Future<http.Response> get(String path, {String? token}) =>
      http.get(uri(path), headers: headers(token));

  Future<http.Response> delete(String path, {String? token}) =>
      http.delete(uri(path), headers: headers(token));

  Future<String> signup(
    String username, [
    String password = 'password123',
  ]) async {
    final r = await post('/api/v1/auth/signup', {
      'username': username,
      'password': password,
    });
    if (r.statusCode != 200) throw StateError('signup failed: ${r.body}');
    return json(r)['token'] as String;
  }

  Future<void> close() async {
    await _server.close(force: true);
    await hub.close();
    await db.close();
  }
}

Map<String, dynamic> json(http.Response r) =>
    jsonDecode(r.body) as Map<String, dynamic>;
