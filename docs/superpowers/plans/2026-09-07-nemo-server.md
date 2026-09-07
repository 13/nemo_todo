# nemo server Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A Dart `shelf` server that stores every user's lists, tasks and subtasks in one SQLite file, syncs them with the app through `POST /api/v1/sync`, supports accounts and shared lists, pushes "changed" pokes over SSE, and serves the built Flutter web app.

**Architecture:** One service class per concern (`AuthService`, `SyncService`, `MembersService`, `EventHub`) over a single drift `ServerDatabase` that reuses the `nemo_core` tables. A thin `createHandler()` wires services into a `shelf_router` with JSON error handling, bearer auth and rate limiting. `bin/nemo_server.dart` parses env config and either serves or runs a maintenance command.

**Tech Stack:** Dart 3.13, shelf 1.4, shelf_router 1.1, shelf_static 1.1, drift 2.34 (`NativeDatabase`, WAL), bcrypt 1.2, crypto 3, args 2, package:test, package:http (tests).

**Spec:** `docs/superpowers/specs/2026-09-07-nemo-design.md`

## Global Constraints

- Workspace member; `dart analyze` clean under `very_good_analysis`; `dart format` applied; generated `*.g.dart` committed.
- Sync semantics exactly as in the spec: LWW via `incomingWins`, one live `sync_log` row per `(entity, row_id, op, list_id/for_user_id)`, pull page size 500, cursor = last `seq` sent, `clock_skew` rejection when the HLC wall clock is more than 3 600 000 ms ahead of server time.
- Sessions: 32 random bytes → base64url token; SHA-256 hex stored; 30-day sliding expiry (extended on use once more than half elapsed).
- Usernames: 3–32 chars of `[a-z0-9_.-]`, stored lowercase. Passwords ≥ 8 chars. bcrypt cost 12.
- Rate limit on `/api/v1/auth/*`: 10 requests per minute per client IP → 429.
- All API responses are JSON; errors are `{"error": "<code>"}` with a fitting status.

## File Structure

- `lib/src/config.dart` — `Config.fromEnv`.
- `lib/src/db/server_tables.dart` — `Users`, `Sessions`, `ListMembers`, `SyncLog`.
- `lib/src/db/server_database.dart` — `ServerDatabase` (+ `.g.dart`), `memory()`, `file(path)`.
- `lib/src/auth/auth_service.dart` — signup/login/authenticate/logout/resetPassword; `AuthUser`, `AuthException`.
- `lib/src/auth/rate_limiter.dart` — `RateLimiter`.
- `lib/src/sync/sync_service.dart` — `SyncService.sync`, `SyncOutcome`.
- `lib/src/sync/members_service.dart` — share/unshare/list.
- `lib/src/sync/sync_log_writer.dart` — `logUpsert`, `logRevoke` helpers used by both services.
- `lib/src/events/event_hub.dart` — `EventHub`, `sseHandler`.
- `lib/src/http/middleware.dart` — JSON errors, bearer auth, security headers, CORS (dev).
- `lib/src/http/static_handler.dart` — web app hosting with SPA fallback.
- `lib/src/http/handler.dart` — `createHandler(...)` router.
- `lib/nemo_server.dart` — exports.
- `bin/nemo_server.dart` — CLI.
- `test/support/test_server.dart` — in-memory server + HTTP helpers.
- Tests: `config_test.dart`, `auth_service_test.dart`, `rate_limiter_test.dart`, `sync_service_test.dart`, `members_service_test.dart`, `event_hub_test.dart`, `handler_test.dart`, `static_handler_test.dart`.

---

### Task 1: Database with shared tables (cross-package spike)

**Outcome (2026-09-07):** spike failed — build_runner never runs drift's analyzer on a dependency package, so `Lists/Tasks/Subtasks` are defined in `lib/src/db/sync_tables.dart` here (and again in the app). Row classes stay shared from `nemo_core`.

**Files:** `lib/src/db/server_tables.dart`, `lib/src/db/server_database.dart`, `test/server_database_test.dart`.

**Interfaces:** Produces `ServerDatabase(QueryExecutor)`, `ServerDatabase.memory()`, `ServerDatabase.file(String path)` (WAL, foreign keys on); tables `users(id pk, username unique, password_hash, created_at)`, `sessions(token_hash pk, user_id, expires_at, created_at)`, `list_members(list_id, user_id, role; pk both)`, `sync_log(seq autoincrement pk, entity, row_id, list_id, for_user_id nullable, op)` with indexes on `list_id` and `for_user_id`.

- [ ] Test: open `ServerDatabase.memory()`, insert a `TaskList` via `toInsertable()`, insert a user and a membership, read back; assert `sqlite_master` lists all seven tables.
- [ ] Implement tables and database; run `dart run build_runner build`.
- [ ] If drift_dev cannot resolve `Lists/Tasks/Subtasks` from `nemo_core`: copy the three table classes into `server_tables.dart` (fallback from the core plan) and record the deviation at the top of this file.
- [ ] Commit `feat(server): database over shared tables`.

### Task 2: Config

**Files:** `lib/src/config.dart`, `test/config_test.dart`.

**Interfaces:** `Config({port=8080, dbPath='/data/nemo.db', allowSignup: bool? (null=auto), webDir='/app/web', corsOrigins=<String>[], nodeId='server'})`, `Config.fromEnv(Map<String,String>)` reading `NEMO_PORT`, `NEMO_DB`, `NEMO_ALLOW_SIGNUP` (`true`/`false`, else null), `NEMO_WEB_DIR`, `NEMO_CORS_ORIGINS` (comma separated).

- [ ] Test: defaults; parsed values; invalid port throws `FormatException`.
- [ ] Implement; commit `feat(server): config from environment`.

### Task 3: Auth service and rate limiter

**Files:** `lib/src/auth/auth_service.dart`, `lib/src/auth/rate_limiter.dart`, tests.

**Interfaces:**
```dart
class AuthUser { final String id; final String username; }
class AuthException implements Exception { final int status; final String code; }
class AuthService {
  AuthService(ServerDatabase db, {bool? allowSignup, DateTime Function()? now, Random? random, int bcryptRounds = 12});
  Future<({AuthUser user, String token})> signup(String username, String password); // 403 signup_disabled, 409 username_taken, 400 invalid_username / weak_password
  Future<({AuthUser user, String token})> login(String username, String password); // 401 invalid_credentials
  Future<AuthUser?> authenticate(String token);   // null when unknown/expired; slides expiry
  Future<void> logout(String token);
  Future<void> resetPassword(String username, String newPassword); // deletes sessions
  Future<bool> get signupOpen; // allowSignup ?? (no users yet)
}
class RateLimiter { RateLimiter({int max = 10, Duration window = const Duration(minutes: 1), DateTime Function()? now}); bool allow(String key); }
```
- [ ] Tests: first signup allowed with policy auto; second blocked (403) with auto, allowed with `allowSignup: true`; duplicate → 409; bad username/password → 400; login wrong password → 401; authenticate returns user, unknown token → null; expired token → null; expiry slides once past half-life; logout invalidates; resetPassword invalidates sessions and allows login with new password; rate limiter allows 10 then blocks the 11th and frees after the window.
- [ ] Implement using `BCrypt.hashpw/checkpw`, `sha256` hex of the token, `Random.secure()` bytes → `base64UrlEncode` without padding.
- [ ] Commit `feat(server): accounts, sessions and rate limiting`.

### Task 4: Sync log writer and sync service

**Files:** `lib/src/sync/sync_log_writer.dart`, `lib/src/sync/sync_service.dart`, `test/sync_service_test.dart`.

**Interfaces:**
```dart
extension SyncLogWriter on ServerDatabase {
  Future<void> logUpsert(SyncEntity entity, String rowId, String listId); // delete live upsert row for (entity,rowId) then insert
  Future<void> logRevoke(SyncEntity entity, String rowId, {String? listId, String? forUserId}); // delete live revoke for same key then insert
  Future<Set<String>> memberUserIds(String listId);
}
class SyncOutcome { final SyncResponse response; final Set<String> notifyUserIds; }
class SyncService {
  SyncService(ServerDatabase db, {HlcClock? clock, DateTime Function()? now, int pageSize = 500, Duration maxSkew = const Duration(hours: 1)});
  Future<SyncOutcome> sync(String userId, SyncRequest request);
}
```
Rules (implement exactly):
1. Load `roles = {listId: role}` for the caller.
2. For each change, validate `Hlc.parse(updatedAt)` (else reject `invalid_hlc`); reject `clock_skew` when `millis > now + maxSkew`.
3. `list`: new → insert with `ownerId = userId`, add owner membership, log upsert. Existing → require role owner (else `forbidden`); if `incomingWins` → update keeping the existing `ownerId`, log upsert.
4. `task`: require role on `row.listId` (else `forbidden`); if existing and `existing.listId != row.listId` require role on the old list too (else `forbidden`). If `incomingWins` → upsert, and when moved: `logRevoke(task, id, listId: old)` and for every subtask of the task `logRevoke(subtask, sid, listId: old)` **before** `logUpsert(task, id, newList)` and `logUpsert(subtask, sid, newList)`.
5. `subtask`: load parent task (else `unknown_task`); require role on its list (else `forbidden`); if `incomingWins` → upsert, log upsert with the task's list.
6. `revoke` from a client → reject `not_allowed`.
7. Accepted rows feed `clock.receive`.
8. Pull: `sync_log where seq > cursor and (list_id in roles.keys or for_user_id = userId) order by seq limit pageSize + 1`; map upsert → current row, revoke → `SyncChange.revoke`; `hasMore`, `cursor`.
9. `members`: for every list in `roles`, `[ListMember(username, role)]` joined through `users`.
10. `notifyUserIds` = union of members of every list touched by accepted changes (including the caller).

- [ ] Tests (each a scenario with a helper `push(userId, changes)`): create list+task then pull from 0 returns both and `members` has the owner; replaying the same push adds no log rows (cursor unchanged); older `updatedAt` does not overwrite newer; 600 tasks → first pull has 500 + `hasMore`, second pull the rest; skew → `rejected: clock_skew`; editor renaming a list → `forbidden`; non-member task → `forbidden`; subtask of unknown task → `unknown_task`; moving a task logs revoke for the old list ahead of the upsert; `notifyUserIds` includes all members.
- [ ] Implement; commit `feat(server): sync endpoint logic`.

### Task 5: Members service

**Files:** `lib/src/sync/members_service.dart`, `test/members_service_test.dart`.

**Interfaces:**
```dart
class MembersException implements Exception { final int status; final String code; }
class MembersService {
  MembersService(ServerDatabase db);
  Future<List<ListMember>> members(String userId, String listId);           // 404 unknown_list when not a member
  Future<Set<String>> share(String ownerId, String listId, String username, MemberRole role); // 403 not_owner, 404 unknown_user, 400 cannot_change_owner; returns user ids to notify
  Future<Set<String>> unshare(String ownerId, String listId, String username); // 403 not_owner, 400 cannot_remove_owner, 404 not_member
}
```
- [ ] Tests: share adds editor and re-logs list, tasks and subtasks (new member pulls them from cursor 0 **and** from a cursor taken before the share); editor may then push a task; unshare inserts `for_user_id` revoke rows for list/tasks/subtasks and the removed member's pull yields revokes; their later push is `forbidden`; non-owner share → 403; removing the owner → 400.
- [ ] Implement; commit `feat(server): shared lists`.

### Task 6: Event hub and SSE

**Files:** `lib/src/events/event_hub.dart`, `test/event_hub_test.dart`.

**Interfaces:** `EventHub({Duration heartbeat = 25 s})`, `Stream<String> subscribe(String userId)` yielding raw SSE frames (`': connected\n\n'`, `'event: changed\ndata: {}\n\n'`, `': ping\n\n'`), `void notify(Iterable<String> userIds)`, `int get connections`, `Future<void> close()`; `Handler sseHandler(EventHub hub, AuthUser user)` returning a streaming `Response` with `text/event-stream`, `Cache-Control: no-cache`, `X-Accel-Buffering: no`, `shelf.io.buffer_output: false`.
- [ ] Tests: notify reaches only subscribed users; two connections of one user both receive; cancelling a subscription drops the connection count; heartbeat frames appear with a fake short interval.
- [ ] Implement; commit `feat(server): SSE change notifications`.

### Task 7: HTTP layer

**Files:** `lib/src/http/middleware.dart`, `lib/src/http/static_handler.dart`, `lib/src/http/handler.dart`, `lib/nemo_server.dart`, `test/support/test_server.dart`, `test/handler_test.dart`, `test/static_handler_test.dart`.

**Interfaces:**
```dart
Handler createHandler({required ServerDatabase db, required Config config, AuthService? auth, SyncService? sync, MembersService? members, EventHub? hub, RateLimiter? limiter, DateTime Function()? now});
```
Routes: `GET /healthz` → `{"status":"ok"}`; `POST /api/v1/auth/signup|login` (rate limited, body `{username,password}` → `{token,username}`); `POST /api/v1/auth/logout`; `GET /api/v1/auth/me` → `{id,username}`; `POST /api/v1/sync` (body `SyncRequest`, → `SyncResponse`, notifies hub); `GET|POST /api/v1/lists/<id>/members`, `DELETE /api/v1/lists/<id>/members/<username>`; `GET /api/v1/events` (bearer header **or** `?token=`); everything else → static handler (`index.html` fallback for extension-less paths; 404 otherwise) with security headers `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy: same-origin`, and a CSP allowing `'self'`, `'wasm-unsafe-eval'`, inline styles, `data:`/`blob:` images and fonts, `blob:` workers. Unknown `/api/...` → 404 JSON. Malformed JSON → 400 `bad_json`. Uncaught errors → 500 `internal`. CORS headers only for origins in `config.corsOrigins` (plus `OPTIONS` preflight).
- [ ] Tests through `http` against `shelf_io.serve` on port 0: health; signup → token → me; login rate limit → 429; sync round trip between two users sharing a list (end-to-end through HTTP); events endpoint streams `event: changed` after the other user's push; static fallback and headers using a temp web dir; 404 JSON for `/api/v1/nope`; 401 without token.
- [ ] Implement; commit `feat(server): HTTP API, static hosting and CLI wiring`.

### Task 8: CLI, Docker and compose

**Files:** `bin/nemo_server.dart`, `Dockerfile`, `.dockerignore`, `docker-compose.yml`, `.env.example`, README section.

- `nemo_server serve` (default): open `Config.fromEnv(Platform.environment)`, `ServerDatabase.file`, `shelf_io.serve(handler, InternetAddress.anyIPv4, port)`, log startup, graceful shutdown on SIGTERM/SIGINT (close hub and db).
- `nemo_server reset-password <username>`: new password from `NEMO_NEW_PASSWORD` or prompted on stdin (echo off).
- Dockerfile stages `web-build` (Flutter 3.47.2 from git, `flutter build web --release --no-web-resources-cdn` in `app/`), `server-build` (`dart:3.13.2`, `dart pub get`, `dart compile exe`), runtime (`debian:bookworm-slim`, `libsqlite3-0`, `ca-certificates`, non-root `nemo` user, `/data` volume, `HEALTHCHECK` curl-free using the compiled binary's `healthcheck` subcommand).
- [ ] Verify: `dart run bin/nemo_server.dart serve` with `NEMO_DB=/tmp/x.db NEMO_WEB_DIR=/tmp/empty` answers `/healthz`; `docker build` runs after the app exists (verified in the app plan's final gate).
- [ ] Commit `feat(server): CLI entrypoint and Docker packaging`.

## Final gate

```bash
cd server && dart run build_runner build && dart format --set-exit-if-changed lib bin test && dart analyze && dart test
```
