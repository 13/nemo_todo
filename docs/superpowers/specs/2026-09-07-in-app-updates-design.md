# In-app updates for Android, published through GitHub

## Goal

nemo is not on any store, so an Android install goes stale the moment a
build is published. The app should notice a newer release on GitHub, tell
the user what changed, download the right APK, and hand it to the system
installer. Publishing a release should be one action: push a tag.

## Decisions

| Topic | Decision |
|---|---|
| Where releases live | GitHub releases on `13/nemo_todo`, assets attached by CI |
| Signing | A new keystore generated for nemo, kept in GitHub secrets. Without one stable key Android refuses every update |
| Which asset | The APK matching the device's ABI, with the universal APK as a fallback |
| When it checks | Once a day at app start, silent on failure, plus a manual check in Settings |
| Publishing | Pushing a `v*` tag builds, signs, and publishes the release |
| Installing | The system installer dialog. The app never installs anything silently |
| Platforms | Android only; the web build has no updater and shows no update UI |

## Why this shape

The Play Store is out because nemo is self-hosted and personal. That leaves
sideloading, and a sideloaded app that cannot tell you it is out of date
stays out of date. GitHub already holds the code, already builds the APKs,
and hands out release assets over HTTPS with a SHA-256 digest per asset, so
no extra hosting or checksum publishing is needed.

The one hard constraint is signing. Android will not replace an installed
app with a package signed by a different key, so a stable release key is not
a nicety here, it is the feature working at all. That is also the strongest
protection available: even if someone served a modified APK, it could not
replace nemo without nemo's key.

## Model

```dart
class AppVersion {            // 0.2.0, compared numerically
  final int major, minor, patch;
  bool isNewerThan(AppVersion other);
}

class ReleaseAsset {
  final String name;          // nemo-0.2.0-arm64-v8a.apk
  final String url;           // browser_download_url
  final int size;
  final String? sha256;       // from the API's `digest` field
}

class AppRelease {
  final AppVersion version;   // parsed from tag_name, minus the leading v
  final String tag;
  final String notes;         // the release body, shown as "what's new"
  final List<ReleaseAsset> assets;
}
```

The updater's state is a sealed union: `idle`, `checking`,
`upToDate(checkedAt)`, `available(release, asset)`, `downloading(progress)`,
`ready(file, release)`, `failed(code)`.

## Components

All under `app/lib/features/updates/`, Android-gated by a single
`updatesSupportedProvider`.

- **`GithubReleaseClient`** asks
  `api.github.com/repos/13/nemo_todo/releases/latest` for the newest
  published release and maps the JSON onto `AppRelease`. Drafts and
  pre-releases never appear at that endpoint, so nothing has to filter them.
- **`AssetSelector`** picks the asset for this device: the first of
  `supportedAbis` (from `device_info_plus`) that matches an asset name,
  otherwise the one ending `-universal.apk`, otherwise nothing.
- **`UpdateDownloader`** streams the asset into the cache directory with a
  progress callback, then hashes it and compares against the asset's digest.
  A mismatch deletes the file and fails; a partial download is discarded.
- **`ApkInstaller`** is an interface with an Android implementation that
  hands the file to the system installer, and a no-op elsewhere so the rest
  of the code needs no platform checks.
- **`UpdateController`** (`keepAlive`) owns the state machine, the daily
  interval, and the `kv` entries for the last check and the dismissed
  version.
- **`UpdateTile`** in Settings shows the running version, the last check and
  one action per state. **`UpdateBanner`** appears above the task list only
  when an update is available and is dismissible for that version.

## Data flow

The app starts, restores its session, and (on Android, at most once every 24
hours) asks GitHub for the latest release. If its version is newer than the
running one, the controller holds `available` and the banner appears.
Tapping it opens a sheet with the release notes and a download button.
Downloading streams the asset to the cache directory, reporting progress,
and verifies the digest. Tapping install opens the system installer, which
asks for permission to install unknown apps the first time and then shows
its normal confirmation. The app's job ends there; Android decides whether
the package may replace the installed one.

Publishing runs the other way. A `v*` tag triggers a release workflow that
checks the tag against the version in `pubspec.yaml`, extracts that
version's section from `CHANGELOG.md`, builds the universal and per-ABI
APKs with the release keystore, creates the GitHub release with the
changelog as its body, and attaches the four files.

## Error handling

An automatic check that fails leaves no trace in the UI: no network, a rate
limit, or a malformed response all return the state to idle, because a todo
app must not nag about its own plumbing. A manual check names the reason.
A failed or corrupted download reports it and offers a retry; nothing
part-downloaded is ever handed to the installer. If no asset matches the
device the update is reported as unavailable for this device rather than
silently doing nothing.

## Security

Everything travels over HTTPS. Each download is verified against the SHA-256
digest GitHub publishes for that asset. Android verifies the package
signature at install time and refuses anything not signed with nemo's key,
which is the guarantee that matters. The app never installs without the user
confirming in the system dialog, and it asks for no storage permissions: the
APK lands in the app's own cache directory.

## Testing

Unit tests cover version parsing and comparison, asset selection against a
device's ABI list, the GitHub JSON mapping including an asset with no
digest, and the downloader's digest check. Controller tests run against a
fake client and a fake installer for: up to date, update available, network
failure while silent, network failure while manual, download progress,
digest mismatch, and install delegation. Widget tests cover the Settings
tile in each state and the banner appearing and staying dismissed. The
system install dialog itself is manual QA on a device, because it belongs to
Android.

## Out of scope

Background or automatic installation, delta updates, rollback, staged
rollout, beta channels, iOS, and any store distribution.

## Follow-up this enables

Signed releases with a changelog are also what a public download page or an
F-Droid style repository would need, if nemo ever wants either.
