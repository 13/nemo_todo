# nemo

A local-first todo app for Android and Web with a self-hosted sync server.

- `app/` — Flutter app (Android + Web). Works fully offline; connects to a server optionally.
- `server/` — Dart `shelf` server: sync API, accounts, shared lists, and hosting of the built web app.
- `packages/nemo_core/` — models, schema and sync logic shared by app and server.
- `docs/superpowers/` — design specs and implementation plans.

## Development

Flutter 3.47.2 / Dart 3.13 (`~/flutter/bin`). This is a Dart pub workspace: run `flutter pub get` once at the repository root.

```bash
export PATH="$HOME/flutter/bin:$PATH"
flutter pub get                       # whole workspace
(cd packages/nemo_core && dart test)
(cd server && dart test)
(cd app && flutter test --coverage && dart run ../tool/check_coverage.dart 80)
(cd app && flutter run -d chrome)     # web dev build
```

Code generation (drift, freezed, riverpod): `dart run build_runner build --delete-conflicting-outputs` inside the package that changed. Generated files are committed.

## Deployment

See `docker-compose.yml`. The container serves the API and the web app on port 8080; put your own TLS reverse proxy in front.
