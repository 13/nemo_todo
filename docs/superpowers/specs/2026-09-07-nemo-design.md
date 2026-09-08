# nemo — local-first todo app with self-hosted sync

## Goal

A modern, intuitive todo app named **nemo** that works fully offline on Android from the first launch, ships as a web app with the identical look and feel, and syncs across devices and users through a small server that runs in Docker on Ben's own machine.

## Decisions

| Topic | Decision |
|---|---|
| Stack | Flutter 3.47.2 / Dart 3.13 for Android and Web from one codebase, mirroring `cuenti_mobile` conventions (Riverpod 3, go_router, freezed, Material 3, Manrope, very_good_analysis) |
| Backend | Dart `shelf` server sharing models, schema and merge logic with the app through the `nemo_core` package; single SQLite file; compiled to a native executable |
| Users | Multiple accounts per server; lists can be shared with other users as owner or editor |
| Account model | Local-first. No account is needed. Connecting to a server later uploads all local data. Sign-out keeps local data |
| Features v1 | Lists with colour and icon plus a default Inbox; due date with optional time and local reminders; subtasks and notes; tags and a four-level priority; Today, Upcoming, per-list and search views |
| Sync | Row-level last-write-wins with hybrid logical clocks (HLC) and tombstones; server change log with an integer cursor; single sync endpoint that pushes and pulls |
| Realtime | Server-sent events (SSE) "changed" poke that makes the client run a normal sync; also on start, resume, connectivity regained, two seconds after a local edit, pull-to-refresh |
| Web layout | Adaptive navigation only: bottom navigation bar on phones, navigation rail above 840 dp, content centred at 720 dp. Same screens everywhere |
| Ordering | Fractional sort keys so reorders never renumber neighbours |
| Reminders | `flutter_local_notifications` inexact scheduling on Android; no-op on web |

## Why row-level LWW with HLC

Every alternative that merges better (operation logs, CRDT libraries) costs an order of magnitude more code on both sides, and a todo app's rows are small: a task, a subtask and a list are separate rows, so concurrent edits to different things never collide. The only real conflicts are two devices editing the same field of the same row while offline, and there "the later edit wins" is what users expect. HLCs keep "later" meaningful across devices whose clocks disagree slightly, and a server-side skew guard stops a badly wrong clock from winning forever.

## Model

All synced rows carry `id` (UUID v4 string), `updated_at` (HLC string, lexicographically sortable) and `deleted_at` (HLC string or null; a tombstone).

| Table | Columns |
|---|---|
| `lists` | `name`, `color` (0..7, index into the palette), `icon` (Material icon name), `sort_key`, `owner_id` (server-authored; the client value is ignored; null while local-only), `is_inbox` |
| `tasks` | `list_id`, `title`, `notes`, `done`, `done_at` (UTC ms, nullable), `due_at` (UTC ms, nullable), `due_has_time`, `remind`, `priority` (0 none .. 3 high), `tags` (JSON array of strings), `sort_key` |
| `subtasks` | `task_id`, `title`, `done`, `sort_key` |

Client-only tables: `outbox(entity, row_id, enqueued_updated_at)` with primary key `(entity, row_id)`; `list_meta(list_id, my_role, members_json)`; `kv(key, value)` for the sync cursor, device node id and HLC state.

Server-only tables: `users(id, username unique, password_hash, created_at)`; `sessions(token_hash primary key, user_id, expires_at)`; `list_members(list_id, user_id, role owner|editor)`; `sync_log(seq autoincrement, entity, row_id, list_id, for_user_id nullable, op upsert|revoke)` holding **one live row per (entity, row_id, for_user_id)**, re-inserted with a new `seq` whenever the row really changes, so the log never grows past the data.

HLC format: `"{wall ms, 13 digits}-{counter, 4 hex digits}-{node id}"`. Comparison is string comparison. Ties are impossible across devices because the node id is part of the string.

## Components

- **`packages/nemo_core`** (pure Dart): `Hlc` (now, receive, parse, compare), `SortKey` (`first`, `last`, `between`), freezed models `TaskList`, `Task`, `Subtask` with JSON, `merge(local, incoming)` for each entity, sync DTOs `SyncRequest`, `SyncResponse`, `SyncChange`, `RejectedChange`, `ListMember`. The drift `Table` classes are declared once per side (`server/lib/src/db/sync_tables.dart` and `app/lib/core/db/sync_tables.dart`) with `@UseRowClass` pointing at these models, so the two databases share the row classes rather than the table code.
- **`server`**: `Config` from environment, `ServerDatabase` (drift `NativeDatabase`, WAL), `AuthService` (bcrypt cost 12, opaque 32-byte tokens hashed with SHA-256, 30-day expiry with rotation after half the lifetime, per-IP rate limit on `/auth/*`, `NEMO_ALLOW_SIGNUP`), `SyncService` (authorise, merge, log, paginate), `MembersService` (share, unshare, fan-out, revoke), `EventHub` (SSE per user, 25 s heartbeat), static hosting of the built web app with SPA fallback and security headers, `GET /healthz`, CLI `reset-password <username>`.
- **`app`**: `AppDatabase` (drift_flutter; wasm worker on web), repositories over DAOs exposing `watch*` streams and writing the outbox in the same transaction, `@riverpod` controllers, `SyncEngine` (keepAlive; single in-flight run with a rerun flag), `SseClient`, `ReminderScheduler` with Android and no-op implementations, theme (`AppTheme`, `NemoColors` extension), shell, router, screens: Today, Upcoming, Lists, List detail, Task detail, Search, Settings, Account, Members.

## Data flow

**Local edit.** UI → controller → repository: stamp `updated_at = hlc.now()`, upsert row, upsert outbox entry, all in one drift transaction. Drift streams refresh every screen. A debounce fires `syncNow()` two seconds later when a server is configured.

**Sync round.** Client reads outbox rows as they are now and sends `POST /api/v1/sync {cursor, changes}`. Server, in one transaction: authorise each change (subtasks resolve their list through their task; tasks through `list_id`; a new list makes the caller its owner; only owners change list rows; HLC more than one hour ahead of server time is rejected as `clock_skew`), `merge`, write only if changed, bump `sync_log`; a task whose `list_id` changed also gets `revoke` entries for the old list (and its subtasks). Then it reads `sync_log` with `seq > cursor` limited to lists the caller belongs to or entries addressed to the caller, ordered by `seq`, at most 500, and answers `{changes, rejected, members, cursor, hasMore, serverHlc}` where `cursor` is the last `seq` sent. Client applies `changes` with the same `merge`, deletes outbox entries whose `updated_at` did not change during the round, drops rejected entries and records a one-time "n changes were discarded" notice, refreshes `list_meta`, persists the cursor, feeds `serverHlc` into its clock, reschedules reminders for changed tasks, and loops while `hasMore`.

**Sharing.** Owner calls `POST /api/v1/lists/{id}/members {username, role}`. Server inserts the membership and re-logs the list, its tasks and subtasks so the new member's next pull receives them; `DELETE .../members/{username}` inserts `revoke` entries addressed to that user, whose client deletes the local copies. Both notify the SSE hub.

**Sign-in.** Cursor is reset to 0 and every local row is enqueued, so a fresh account receives all local data and an existing account merges by LWW. **Sign-out** clears token, cursor and `list_meta` but keeps rows.

## Error handling

- Network failures leave the outbox untouched; the next trigger retries. Sync status in Settings shows last success and pending count.
- Rejected changes are dropped from the outbox and the user sees a single notice per round. A change that is accepted but loses to a newer row is answered with the winning row in the same response, and the losing device drops its queued copy when it applies it, so a loss corrects itself rather than sitting in the queue.
- SSE reconnects with exponential backoff (1 s → 60 s); a reconnect triggers a sync.
- Server returns JSON `{error}` bodies; 401 clears the token client-side and shows "signed out" in Settings; 429 on auth endpoints shows "too many attempts".
- Tombstoned lists hide their tasks; nothing cascades, so an offline undo of a list deletion restores its tasks. A server maintenance command may purge rows tombstoned for over 30 days (backlog).

## Testing

- `nemo_core`: unit tests for HLC ordering and receive, sort keys, merge semantics, JSON round trips.
- `server`: handler tests through `shelf` `Request` objects with an in-memory database; idempotent retries, pagination, skew rejection, role enforcement, share/unshare/move fan-out, SSE broadcast.
- `app`: DAO tests on an in-memory database, controller tests, widget tests per screen with mocktail overrides, sync engine tests against a fake HTTP layer, reminder scheduler tests with a fake plugin. Coverage floor 80 % via `tool/check_coverage.dart`.
- `server/test/e2e_sync_test.dart`: two in-memory app sync engines against an in-process server: share, concurrent edits, offline conflict, move between lists, revoke → convergence.
- CI: generated-code staleness gate, format, analyze, tests, web build, APK build, Docker build.

## Out of scope

Recurring tasks, attachments, list ownership transfer, password reset by e-mail, server push notifications, home-screen widget, iOS, master-detail desktop layout, end-to-end encryption, Postgres.

## Follow-up this enables

The change log and membership model support later features such as activity history, shared-list comments and per-list notifications without changing the row schema.
