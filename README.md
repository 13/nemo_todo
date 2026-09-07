# nemo

A local-first todo app for Android and the web, with a small sync server you
host yourself.

- Works completely offline from the first launch. An account is optional.
- Lists with colours and icons, due dates with reminders, subtasks, notes,
  tags and four priorities, plus Today, Upcoming and search views.
- Connect it to your server later and everything already on the device is
  uploaded. Signing out keeps your tasks.
- Lists can be shared with other accounts on the same server.
- The web app is the same app: identical screens, with a navigation rail
  instead of a bottom bar on wide windows.

## Layout

| Path | What it is |
|---|---|
| `app/` | The Flutter app for Android and the web |
| `server/` | The Dart server: sync API, accounts, sharing, and hosting of the web app |
| `packages/nemo_core/` | Models, sync protocol and merge rules shared by both |
| `docs/superpowers/` | Design spec and implementation plans |

## How syncing works

Every row carries a hybrid logical clock stamp. A device writes to its own
database first and queues the row; a sync sends the queue and asks for
everything past a cursor the server hands out. When two devices change the
same row, the higher stamp wins, which is what "the last edit wins" means
when clocks disagree slightly. Deletions are tombstones, so they travel like
any other change. The server keeps one change-log row per record, so the log
never outgrows the data. While the app is open it holds a lightweight
server-sent-events stream: the server only says "something changed" and the
app runs a normal sync.

`docs/superpowers/specs/2026-09-07-nemo-design.md` has the details.

## Development

Flutter 3.47.2 / Dart 3.13. This is a pub workspace, so dependencies are
resolved once at the root.

```bash
export PATH="$HOME/flutter/bin:$PATH"
flutter pub get
tool/fetch_web_assets.sh                     # sqlite3.wasm + drift worker

(cd packages/nemo_core && dart test)
(cd server && dart test)
(cd app && flutter test --coverage && dart run ../tool/check_coverage.dart 80)

(cd app && flutter run -d chrome)            # the app against a dev server
```

To look at the design without a device, render every screen to
`app/build/screens/*.png`:

```bash
(cd app && flutter test test/design --update-goldens)
```

Those images are build output rather than stored golden assertions, so the
normal test run skips them (`--exclude-tags design`).

Code generation (drift, freezed, riverpod) runs per package with
`dart run build_runner build`; generated files are committed and CI fails if
they are stale.

The server is compiled with `dart build cli`, not `dart compile exe`: the
sqlite3 package ships a build hook, and only `dart build` runs hooks and
places the native library next to the executable.

To run the app against a server on your machine, start the server with
`NEMO_CORS_ORIGINS` naming the dev origin, then enter its address on the
Connect screen in Settings.

## Running the server

```bash
cp .env.example .env
docker compose up --build -d
```

The container serves the API and the web app on port 8080 and keeps its
SQLite database in the `nemo_data` volume. Put your own TLS reverse proxy in
front of it; nothing in the container terminates TLS.

| Variable | Meaning |
|---|---|
| `NEMO_PORT` | Listen port, default 8080 |
| `NEMO_DB` | Database file, default `/data/nemo.db` |
| `NEMO_ALLOW_SIGNUP` | `true`, `false`, or empty for "open until the first account exists" |
| `NEMO_WEB_DIR` | Where the built web app lives, default `/app/web` |
| `NEMO_CORS_ORIGINS` | Comma-separated origins allowed to call the API, for development |

Forgotten password:

```bash
docker compose exec nemo nemo_server reset-password <username>
```

## Security notes

- Sessions are opaque random tokens; only their hashes are stored, they
  expire after 30 days, and an active session renews itself.
- Passwords are hashed with bcrypt. Sign-up is rate limited per address.
- On Android the session token lives in the platform keystore. On the web
  there is no such vault: it ends up in browser storage, readable by any
  script that manages to run on the page. The served app sets a strict
  content security policy, but treat a shared or untrusted browser
  accordingly.
- A device whose clock is more than an hour ahead of the server is refused
  rather than allowed to win every conflict for ever.

## Android

`minSdk` is 26. Reminders use inexact alarms, so Android may shift them by a
few minutes to save battery; they survive a reboot. The web build has no
reminders.
