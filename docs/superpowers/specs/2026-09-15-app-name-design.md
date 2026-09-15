# The app is called "nemo todo"

## Goal

Wherever the app is named on its own — the Android launcher, the app
switcher, the browser tab, a home-screen web app, the window title and About —
it reads "nemo todo" instead of "nemo". A bare "nemo" says nothing about what
the app does; "nemo todo" does, and matches the repository name.

## Decisions

| Topic | Decision |
|---|---|
| New name | `nemo todo`, lowercase, like the current name |
| Scope | Only places that show the app's name by itself |
| Translation | Not translated: the same `nemo todo` in English, German and Italian |
| Sentences that mention nemo | Unchanged ("nemo is up to date", "not a nemo export", ...) |
| Logo and wordmark | Unchanged |
| Identifiers | Unchanged: package id `dev.ben.nemo`, database name `nemo`, APK file names, Docker image, server name |
| Guard | One test keeps every place that names the app in agreement |

## Why this shape

The name lives in three places that each platform reads directly: the Android
manifest, the web app manifest with the page head, and the app's own strings.
Generating the Android label from the Flutter strings at build time would give
one source of truth but adds Gradle plumbing for a single word. A test that
fails when the places disagree gives the same protection with no build change.

Identifiers stay as they are because they are not names a person reads: the
package id and database name hold existing installs and data, the updater
picks APKs by their `-<abi>.apk` suffix, and images and servers are addressed
by those names in deployments.

## What changes

- `app/android/app/src/main/AndroidManifest.xml`: `android:label="nemo todo"`
  (launcher label and app switcher). It is the only manifest with a label.
- `app/web/manifest.json`: `"name"` and `"short_name"` become `nemo todo`
  (9 characters, within what a home-screen label shows).
- `app/web/index.html`: `<title>` and the `apple-mobile-web-app-title` meta
  become `nemo todo`. The server serves this file unchanged (it only sets
  cache headers), so nothing on the server side needs to follow.
- `app/lib/l10n/app_en.arb`, `app_de.arb`, `app_it.arb`: `appName` becomes
  `nemo todo`; `flutter gen-l10n` regenerates `app_localizations*.dart`.
  `appName` is used by `MaterialApp.onGenerateTitle` (window and task switcher),
  the startup error screen's title, the About tile heading and the licence page
  (`showAboutDialog`'s `applicationName`).
- `CHANGELOG.md`: under `## Unreleased`, a `### Changed` section (placed between
  `### Added` and `### Fixed`, following the Added/Changed/Fixed/Removed order)
  with one bullet: the app is now called nemo todo on the home screen, in the
  browser tab and in About.

## The guard test

`app/test/app_name_test.dart`, a plain `test` (no widgets):

- `appName` is `nemo todo` for every locale in `L.supportedLocales`.
- `app/android/app/src/main/AndroidManifest.xml` has
  `android:label="nemo todo"`.
- `app/web/manifest.json` parses as JSON and has `name` and `short_name`
  equal to `nemo todo`.
- `app/web/index.html` has `<title>nemo todo</title>` and an
  `apple-mobile-web-app-title` meta with `content="nemo todo"`.

Paths are relative to `app/`, where `flutter test` runs (as the existing
`test/l10n/translations_test.dart` does for the ARB files). The expected name
is one constant at the top of the test.

## Effect on existing installs

- Android: the launcher label changes with the next update.
- Web: the tab title changes on the next load. A web app already added to a
  home screen may keep showing "nemo" until it is removed and added again;
  browsers cache that label, and nothing the app can do changes it.

## Out of scope

The sentences that mention nemo, the wordmark SVGs and README header image,
README and docs text, and every identifier listed above.

## Verification

The new test; `flutter test --exclude-tags design`; `flutter analyze`;
`dart format` check; `flutter build web --release --no-web-resources-cdn` and a
look at `build/web/index.html` and `build/web/manifest.json` for the new name.
