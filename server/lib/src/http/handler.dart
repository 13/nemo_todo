import 'package:nemo_core/nemo_core.dart';
import 'package:nemo_server/src/api_exception.dart';
import 'package:nemo_server/src/auth/auth_service.dart';
import 'package:nemo_server/src/auth/rate_limiter.dart';
import 'package:nemo_server/src/config.dart';
import 'package:nemo_server/src/db/server_database.dart';
import 'package:nemo_server/src/events/event_hub.dart';
import 'package:nemo_server/src/http/middleware.dart';
import 'package:nemo_server/src/http/static_handler.dart';
import 'package:nemo_server/src/sync/members_service.dart';
import 'package:nemo_server/src/sync/sync_service.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

/// Builds the complete request handler: API under `/api/v1`, health check,
/// SSE stream and the web app for everything else.
Handler createHandler({
  required ServerDatabase db,
  required Config config,
  AuthService? auth,
  SyncService? sync,
  MembersService? members,
  EventHub? hub,
  RateLimiter? limiter,
  DateTime Function()? now,
}) {
  final authService =
      auth ?? AuthService(db, allowSignup: config.allowSignup, now: now);
  final syncService =
      sync ??
      SyncService(
        db,
        clock: HlcClock(node: config.nodeId),
        now: now,
      );
  final membersService = members ?? MembersService(db);
  final eventHub = hub ?? EventHub();
  final rateLimiter = limiter ?? RateLimiter(now: now);

  Future<Response> credentials(
    Request request,
    Future<AuthResult> Function(String username, String password) call,
  ) async {
    final body = await readJson(request);
    final result = await call(
      body['username'] as String? ?? '',
      body['password'] as String? ?? '',
    );
    return jsonResponse({
      'token': result.token,
      'username': result.user.username,
    });
  }

  final limited = const Pipeline().addMiddleware(rateLimit(rateLimiter));

  final api = Router()
    ..post('/auth/logout', (Request request) async {
      await authService.logout(request.token);
      return jsonResponse({'ok': true});
    })
    ..get(
      '/auth/me',
      (Request request) => jsonResponse({
        'id': request.user.id,
        'username': request.user.username,
      }),
    )
    ..post('/sync', (Request request) async {
      final body = await readJson(request);
      final SyncRequest syncRequest;
      try {
        syncRequest = SyncRequest.fromJson(body);
      } on Object {
        throw const ApiException(400, 'bad_request');
      }
      final outcome = await syncService.sync(request.user.id, syncRequest);
      eventHub.notify(outcome.notifyUserIds);
      return jsonResponse(outcome.response.toJson());
    })
    ..get('/lists/<id>/members', (Request request, String id) async {
      final list = await membersService.members(request.user.id, id);
      return jsonResponse({
        'members': [for (final m in list) m.toJson()],
      });
    })
    ..post('/lists/<id>/members', (Request request, String id) async {
      final body = await readJson(request);
      final username = body['username'] as String? ?? '';
      final role = MemberRole.values
          .asNameMap()[body['role'] as String? ?? 'editor'];
      if (role == null) throw const ApiException(400, 'bad_request');
      final notify = await membersService.share(
        request.user.id,
        id,
        username,
        role,
      );
      eventHub.notify(notify);
      return jsonResponse({'ok': true});
    })
    ..delete('/lists/<id>/members/<username>', (
      Request request,
      String id,
      String username,
    ) async {
      final notify = await membersService.unshare(
        request.user.id,
        id,
        username,
      );
      eventHub.notify(notify);
      return jsonResponse({'ok': true});
    })
    ..all('/<ignored|.*>', (Request _) => errorResponse(404, 'not_found'));

  final router = Router()
    ..get('/healthz', (Request _) => jsonResponse({'status': 'ok'}))
    ..post(
      '/api/v1/auth/signup',
      limited.addHandler((r) => credentials(r, authService.signup)),
    )
    ..post(
      '/api/v1/auth/login',
      limited.addHandler((r) => credentials(r, authService.login)),
    )
    ..get(
      '/api/v1/events',
      const Pipeline()
          .addMiddleware(requireAuth(authService, allowQueryToken: true))
          .addHandler((request) => sseResponse(eventHub, request.user.id)),
    )
    ..mount(
      '/api/v1/',
      const Pipeline()
          .addMiddleware(requireAuth(authService))
          .addHandler(api.call),
    )
    ..all('/api/<ignored|.*>', (Request _) => errorResponse(404, 'not_found'))
    ..all('/<ignored|.*>', webAppHandler(config.webDir));

  return const Pipeline()
      .addMiddleware(requestLogging())
      .addMiddleware(cors(config.corsOrigins))
      .addMiddleware(securityHeaders())
      .addMiddleware(jsonErrors())
      .addHandler(router.call);
}
