# In-app Android updates Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** nemo on Android notices a newer GitHub release, shows what changed, downloads the APK for the device and hands it to the system installer; pushing a `v*` tag publishes that release.

**Architecture:** A self-contained `features/updates` slice: a GitHub client, an asset picker, a verifying downloader, an installer behind an interface, and one `keepAlive` controller holding a sealed state. Settings shows the state and a manual check; a dismissible banner on Today is how an update announces itself. A separate release workflow builds and signs on tags.

**Tech Stack:** Flutter 3.47.2, dio 5.11 (already present), package_info_plus 10.2.1, device_info_plus 13.2.0, crypto 3.0.7, open_filex 4.7.0, Riverpod 3, freezed 4, GitHub Actions with the `gh` CLI.

**Spec:** `docs/superpowers/specs/2026-09-07-in-app-updates-design.md`

## Global Constraints

- Android only. Every entry point is gated on `updatesSupportedProvider`; the web build must not import `dart:io`-only paths at runtime or show update UI.
- `flutter analyze` clean under `very_good_analysis`; `dart format` applied; generated files committed; app coverage stays at or above 80 % (`dart run ../tool/check_coverage.dart 80`).
- All user-visible strings go through `L.of(context)` with entries in `app_en.arb`, `app_de.arb` and `app_it.arb`; `test/l10n/translations_test.dart` enforces identical key sets.
- Releases live at `https://api.github.com/repos/13/nemo_todo/releases/latest`. Asset names are `nemo-<version>+<build>-<abi>.apk` and `nemo-<version>+<build>-universal.apk`.
- Automatic checks fail silently; manual checks report the reason.
- Nothing installs without the system dialog. No storage permission is requested: downloads go to the app's own cache directory.
- The repository is public, so the client sends no token and lives within the anonymous rate limit of 60 requests per hour.

## File Structure

```
app/lib/features/updates/
  domain/app_version.dart          AppVersion: parse "0.2.0", compare
  domain/app_release.dart          AppRelease, ReleaseAsset (freezed)
  domain/asset_selector.dart       pick an asset for a device's ABIs
  data/github_release_client.dart  latest release over dio; typed failures
  data/update_downloader.dart      stream to cache, verify sha256
  data/apk_installer.dart          interface + Android and no-op impls
  ui/update_state.dart             sealed UpdateState
  ui/update_controller.dart        the state machine and its providers
  ui/update_tile.dart              Settings entry
  ui/update_banner.dart            dismissible line on Today
app/test/features/updates/…        one test file per unit above
app/test/support/fake_updates.dart FakeReleaseClient, FakeInstaller, fixtures
.github/workflows/release.yml      tag -> signed build -> GitHub release
CHANGELOG.md                       one section per version, used as the notes
```

Modified: `app/pubspec.yaml` (four dependencies), `app/lib/core/providers.dart` (platform gate), `app/lib/core/db/kv_store.dart` (two keys), `app/lib/features/settings/ui/settings_screen.dart`, `app/lib/features/tasks/ui/today_screen.dart`, `app/lib/app.dart` (startup check), `app/android/app/src/main/AndroidManifest.xml` (one permission), the three `.arb` catalogues, `README.md`.

---

### Task 0: A signing key, and the secrets CI needs

Without one stable key Android refuses every update, so this comes first. It
is the only task that is not code.

**Files:** Create `~/nemo-release.jks` (outside the repository),
`app/android/key.properties` (gitignored). No repository files change.

**Interfaces:** Produces four GitHub secrets consumed by Task 8:
`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`,
`ANDROID_KEY_PASSWORD`. `app/android/app/build.gradle.kts` already reads
`key.properties` and falls back to the debug key when it is absent.

- [ ] **Step 1: Generate the key**

```bash
keytool -genkeypair -v -keystore ~/nemo-release.jks \
  -alias nemo -keyalg RSA -keysize 4096 -validity 10000 \
  -dname "CN=nemo, O=nemo, C=IT" \
  -storepass "$NEMO_KEYSTORE_PASSWORD" -keypass "$NEMO_KEYSTORE_PASSWORD"
```

Pick the password first and export it as `NEMO_KEYSTORE_PASSWORD` for this
shell only. 10000 days is roughly 27 years; a key that expires is a key that
ends updates.

- [ ] **Step 2: Point local release builds at it**

```bash
cat > app/android/key.properties <<PROPS
storeFile=$HOME/nemo-release.jks
storePassword=$NEMO_KEYSTORE_PASSWORD
keyAlias=nemo
keyPassword=$NEMO_KEYSTORE_PASSWORD
PROPS
```

`app/android/key.properties` is already in `.gitignore`. Confirm with
`git check-ignore -v app/android/key.properties` before continuing.

- [ ] **Step 3: Verify a build is signed with it**

```bash
export PATH="$HOME/flutter/bin:$PATH" ANDROID_HOME="$HOME/Android/Sdk"
(cd app && flutter build apk --release --split-per-abi)
"$ANDROID_HOME"/build-tools/36.0.0/apksigner verify --print-certs \
  app/build/app/outputs/release/nemo-*-arm64-v8a.apk | head -4
```

Expected: a certificate whose DN is `CN=nemo`, not `CN=Android Debug`.

- [ ] **Step 4: Give CI the same key**

```bash
base64 -w0 ~/nemo-release.jks | gh secret set ANDROID_KEYSTORE_BASE64 --repo 13/nemo_todo
printf '%s' "$NEMO_KEYSTORE_PASSWORD" | gh secret set ANDROID_KEYSTORE_PASSWORD --repo 13/nemo_todo
printf 'nemo' | gh secret set ANDROID_KEY_ALIAS --repo 13/nemo_todo
printf '%s' "$NEMO_KEYSTORE_PASSWORD" | gh secret set ANDROID_KEY_PASSWORD --repo 13/nemo_todo
gh secret list --repo 13/nemo_todo
```

- [ ] **Step 5: Write down what must survive**

Back up `~/nemo-release.jks` and its password somewhere that is not this
machine. If both are lost, no future build can update an installed nemo:
every user has to uninstall and lose their local tasks. Note in
`docs/backlog.md` that the debug-signed APKs handed out before this task
cannot be updated in place and must be uninstalled once.

---

### Task 1: Version parsing and comparison

**Files:**
- Create: `app/lib/features/updates/domain/app_version.dart`
- Test: `app/test/features/updates/app_version_test.dart`

**Interfaces:** Produces `class AppVersion implements Comparable<AppVersion>`
with `AppVersion(int major, int minor, int patch)`,
`static AppVersion? tryParse(String)` (accepts `1.2.3`, `v1.2.3` and
`1.2.3+4`, ignoring the build), `bool isNewerThan(AppVersion other)`,
`String toString()` returning `1.2.3`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/updates/domain/app_version.dart';

void main() {
  test('parses plain, tagged and build-suffixed versions', () {
    expect(AppVersion.tryParse('1.2.3'), const AppVersion(1, 2, 3));
    expect(AppVersion.tryParse('v1.2.3'), const AppVersion(1, 2, 3));
    expect(AppVersion.tryParse('0.1.0+7'), const AppVersion(0, 1, 0));
    expect(AppVersion.tryParse(' v2.0.0 '), const AppVersion(2, 0, 0));
  });

  test('rejects anything that is not three numbers', () {
    for (final input in ['', 'v', '1.2', '1.2.3.4', 'nightly', '1.2.x']) {
      expect(AppVersion.tryParse(input), isNull, reason: input);
    }
  });

  test('compares by major, then minor, then patch', () {
    expect(const AppVersion(1, 0, 0).isNewerThan(const AppVersion(0, 9, 9)), isTrue);
    expect(const AppVersion(0, 2, 0).isNewerThan(const AppVersion(0, 1, 9)), isTrue);
    expect(const AppVersion(0, 1, 2).isNewerThan(const AppVersion(0, 1, 1)), isTrue);
    expect(const AppVersion(0, 1, 1).isNewerThan(const AppVersion(0, 1, 1)), isFalse);
    expect(const AppVersion(0, 1, 0).isNewerThan(const AppVersion(0, 1, 1)), isFalse);
    // Ten is greater than nine, which string comparison gets wrong.
    expect(const AppVersion(0, 10, 0).isNewerThan(const AppVersion(0, 9, 0)), isTrue);
  });

  test('prints back the way it came in', () {
    expect(AppVersion.tryParse('v1.2.3').toString(), '1.2.3');
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `cd app && flutter test test/features/updates/app_version_test.dart`
Expected: compile failure, `app_version.dart` does not exist.

- [ ] **Step 3: Implement**

```dart
import 'package:meta/meta.dart';

/// A release version, three numbers. Build suffixes are accepted and
/// dropped: Android needs the build number to increase, but whether an
/// update exists is decided on the version alone.
@immutable
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.major, this.minor, this.patch);

  static final _pattern = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)(?:\+\d+)?$');

  static AppVersion? tryParse(String value) {
    final match = _pattern.firstMatch(value.trim());
    if (match == null) return null;
    return AppVersion(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  final int major;
  final int minor;
  final int patch;

  bool isNewerThan(AppVersion other) => compareTo(other) > 0;

  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  @override
  String toString() => '$major.$minor.$patch';

  @override
  bool operator ==(Object other) =>
      other is AppVersion &&
      other.major == major &&
      other.minor == minor &&
      other.patch == patch;

  @override
  int get hashCode => Object.hash(major, minor, patch);
}
```

- [ ] **Step 4: Run the test again**

Expected: PASS. Then `flutter analyze` clean.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/updates/domain/app_version.dart \
        app/test/features/updates/app_version_test.dart
git commit -m "feat(updates): compare release versions"
```

---

### Task 2: The release model and the GitHub client

**Files:**
- Modify: `app/pubspec.yaml` (add `crypto: ^3.0.7`, `device_info_plus: ^13.2.0`, `package_info_plus: ^10.2.1`, `open_filex: ^4.7.0`)
- Create: `app/lib/features/updates/domain/app_release.dart`
- Create: `app/lib/features/updates/data/github_release_client.dart`
- Test: `app/test/features/updates/github_release_client_test.dart`

**Interfaces:** Produces

```dart
@freezed abstract class ReleaseAsset with _$ReleaseAsset {
  const factory ReleaseAsset({
    required String name, required String url, required int size, String? sha256,
  }) = _ReleaseAsset;
}
@freezed abstract class AppRelease with _$AppRelease {
  const factory AppRelease({
    required AppVersion version, required String tag, required String notes,
    required List<ReleaseAsset> assets,
  }) = _AppRelease;
}
enum UpdateFailure { network, rateLimited, notFound, malformed }
class UpdateException implements Exception { const UpdateException(this.failure); final UpdateFailure failure; }
class GithubReleaseClient {
  GithubReleaseClient(Dio dio, {String repository = '13/nemo_todo'});
  Future<AppRelease> latest();   // throws UpdateException
}
```

`AppVersion` has no JSON codec, so `AppRelease` is hand-mapped rather than
`json_serializable`; only `freezed` runs on this file.

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/updates/data/github_release_client.dart';
import 'package:nemo/features/updates/domain/app_version.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.respond);
  final ResponseBody Function(RequestOptions options) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? s,
      Future<void>? c) async {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, {int status = 200}) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );

Dio _dio(_FakeAdapter adapter) =>
    Dio(BaseOptions(validateStatus: (s) => s != null && s < 400))
      ..httpClientAdapter = adapter;

const _release = {
  'tag_name': 'v0.2.0',
  'body': '- Faster search\n- Fixed reminders',
  'assets': [
    {
      'name': 'nemo-0.2.0+2-arm64-v8a.apk',
      'browser_download_url': 'https://example.test/arm64.apk',
      'size': 24000000,
      'digest': 'sha256:abc123',
    },
    {
      'name': 'SHA256SUMS.txt',
      'browser_download_url': 'https://example.test/sums',
      'size': 120,
    },
  ],
};

void main() {
  test('maps a release, its notes and its assets', () async {
    final adapter = _FakeAdapter((_) => _json(_release));
    final release = await GithubReleaseClient(_dio(adapter)).latest();

    expect(release.version, const AppVersion(0, 2, 0));
    expect(release.tag, 'v0.2.0');
    expect(release.notes, contains('Faster search'));
    expect(release.assets, hasLength(2));
    final apk = release.assets.first;
    expect(apk.name, 'nemo-0.2.0+2-arm64-v8a.apk');
    expect(apk.url, 'https://example.test/arm64.apk');
    expect(apk.size, 24000000);
    // The digest arrives prefixed; the bare hash is what a checksum needs.
    expect(apk.sha256, 'abc123');
    expect(release.assets.last.sha256, isNull);

    final sent = adapter.requests.single;
    expect(sent.uri.toString(),
        'https://api.github.com/repos/13/nemo_todo/releases/latest');
    expect(sent.headers['Accept'], 'application/vnd.github+json');
  });

  test('a tag that is not a version is malformed', () async {
    final adapter =
        _FakeAdapter((_) => _json({..._release, 'tag_name': 'nightly'}));
    await expectLater(
      GithubReleaseClient(_dio(adapter)).latest(),
      throwsA(isA<UpdateException>()
          .having((e) => e.failure, 'failure', UpdateFailure.malformed)),
    );
  });

  test('maps the statuses that matter', () async {
    Future<void> expectFailure(int status, UpdateFailure failure) async {
      final client = GithubReleaseClient(
        _dio(_FakeAdapter((_) => _json({'message': 'no'}, status: status))),
      );
      await expectLater(
        client.latest(),
        throwsA(isA<UpdateException>().having((e) => e.failure, 'failure', failure)),
      );
    }

    await expectFailure(403, UpdateFailure.rateLimited);
    await expectFailure(404, UpdateFailure.notFound);
    await expectFailure(500, UpdateFailure.network);
  });

  test('an unreachable host is a network failure', () async {
    final client = GithubReleaseClient(_dio(_FakeAdapter((options) =>
        throw DioException.connectionError(
            requestOptions: options, reason: 'offline'))));
    await expectLater(
      client.latest(),
      throwsA(isA<UpdateException>()
          .having((e) => e.failure, 'failure', UpdateFailure.network)),
    );
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `cd app && flutter test test/features/updates/github_release_client_test.dart`
Expected: compile failure.

- [ ] **Step 3: Add the dependencies**

```bash
cd app
flutter pub add crypto:^3.0.7 device_info_plus:^13.2.0 \
                package_info_plus:^10.2.1 open_filex:^4.7.0
```

- [ ] **Step 4: Implement the model**

```dart
// app/lib/features/updates/domain/app_release.dart
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nemo/features/updates/domain/app_version.dart';

part 'app_release.freezed.dart';

@freezed
abstract class ReleaseAsset with _$ReleaseAsset {
  const factory ReleaseAsset({
    required String name,
    required String url,
    required int size,
    /// Hex digest GitHub publishes for the asset, without its algorithm
    /// prefix. Null for assets uploaded before GitHub recorded one.
    String? sha256,
  }) = _ReleaseAsset;
}

@freezed
abstract class AppRelease with _$AppRelease {
  const factory AppRelease({
    required AppVersion version,
    required String tag,
    required String notes,
    required List<ReleaseAsset> assets,
  }) = _AppRelease;
}
```

- [ ] **Step 5: Implement the client**

```dart
// app/lib/features/updates/data/github_release_client.dart
import 'package:dio/dio.dart';
import 'package:nemo/features/updates/domain/app_release.dart';
import 'package:nemo/features/updates/domain/app_version.dart';

enum UpdateFailure { network, rateLimited, notFound, malformed }

class UpdateException implements Exception {
  const UpdateException(this.failure);
  final UpdateFailure failure;
  @override
  String toString() => 'UpdateException(${failure.name})';
}

/// Reads the newest published release. Drafts and pre-releases never
/// appear at this endpoint, so nothing has to filter them out.
class GithubReleaseClient {
  GithubReleaseClient(this._dio, {this.repository = '13/nemo_todo'});

  final Dio _dio;
  final String repository;

  Future<AppRelease> latest() async {
    final Map<String, dynamic> body;
    try {
      final response = await _dio.getUri<Map<String, dynamic>>(
        Uri.parse('https://api.github.com/repos/$repository/releases/latest'),
        options: Options(
          headers: {'Accept': 'application/vnd.github+json'},
          receiveTimeout: const Duration(seconds: 15),
        ),
      );
      body = response.data ?? (throw const UpdateException(UpdateFailure.malformed));
    } on DioException catch (e) {
      throw UpdateException(switch (e.response?.statusCode) {
        403 || 429 => UpdateFailure.rateLimited,
        404 => UpdateFailure.notFound,
        _ => UpdateFailure.network,
      });
    }

    final tag = body['tag_name'] as String? ?? '';
    final version = AppVersion.tryParse(tag);
    if (version == null) throw const UpdateException(UpdateFailure.malformed);

    return AppRelease(
      version: version,
      tag: tag,
      notes: (body['body'] as String? ?? '').trim(),
      assets: [
        for (final asset in body['assets'] as List<dynamic>? ?? const [])
          if (asset is Map<String, dynamic>)
            ReleaseAsset(
              name: asset['name'] as String? ?? '',
              url: asset['browser_download_url'] as String? ?? '',
              size: asset['size'] as int? ?? 0,
              // The API returns "sha256:<hex>"; keep the hex.
              sha256: (asset['digest'] as String?)?.split(':').last,
            ),
      ],
    );
  }
}
```

- [ ] **Step 6: Generate, run, commit**

```bash
cd app && dart run build_runner build && dart format lib test
flutter test test/features/updates/github_release_client_test.dart
git add app/pubspec.yaml app/pubspec.lock pubspec.lock app/lib/features/updates app/test/features/updates
git commit -m "feat(updates): read the latest release from GitHub"
```

---

### Task 3: Choosing the asset for this device

**Files:**
- Create: `app/lib/features/updates/domain/asset_selector.dart`
- Test: `app/test/features/updates/asset_selector_test.dart`

**Interfaces:** Produces
`ReleaseAsset? selectAsset(List<ReleaseAsset> assets, List<String> supportedAbis)`.
Matches `-<abi>.apk` in the device's own order of preference, then
`-universal.apk`, then gives up. Non-APK assets are never returned.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/updates/domain/app_release.dart';
import 'package:nemo/features/updates/domain/asset_selector.dart';

ReleaseAsset _asset(String name) =>
    ReleaseAsset(name: name, url: 'https://example.test/$name', size: 1);

final _assets = [
  _asset('nemo-0.2.0+2-arm64-v8a.apk'),
  _asset('nemo-0.2.0+2-armeabi-v7a.apk'),
  _asset('nemo-0.2.0+2-x86_64.apk'),
  _asset('nemo-0.2.0+2-universal.apk'),
  _asset('SHA256SUMS.txt'),
];

void main() {
  test('takes the first supported abi, in the device order', () {
    expect(selectAsset(_assets, ['arm64-v8a', 'armeabi-v7a'])!.name,
        'nemo-0.2.0+2-arm64-v8a.apk');
    // A 32 bit device lists only its own architecture.
    expect(selectAsset(_assets, ['armeabi-v7a'])!.name,
        'nemo-0.2.0+2-armeabi-v7a.apk');
    expect(selectAsset(_assets, ['x86_64', 'x86'])!.name,
        'nemo-0.2.0+2-x86_64.apk');
  });

  test('falls back to the universal build', () {
    expect(selectAsset(_assets, ['riscv64'])!.name, 'nemo-0.2.0+2-universal.apk');
    expect(selectAsset(_assets, [])!.name, 'nemo-0.2.0+2-universal.apk');
  });

  test('returns nothing when no apk fits', () {
    final onlyOther = [_asset('SHA256SUMS.txt'), _asset('sources.zip')];
    expect(selectAsset(onlyOther, ['arm64-v8a']), isNull);
    expect(selectAsset(const [], ['arm64-v8a']), isNull);
  });

  test('never offers a file that is not an apk', () {
    final trap = [_asset('nemo-0.2.0+2-arm64-v8a.apk.asc')];
    expect(selectAsset(trap, ['arm64-v8a']), isNull);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `cd app && flutter test test/features/updates/asset_selector_test.dart`

- [ ] **Step 3: Implement**

```dart
import 'package:nemo/features/updates/domain/app_release.dart';

/// The APK to download on a device reporting [supportedAbis], which Android
/// gives in the device's own order of preference. Falls back to the
/// universal build, which runs anywhere at three times the size.
ReleaseAsset? selectAsset(
  List<ReleaseAsset> assets,
  List<String> supportedAbis,
) {
  final apks = assets.where((a) => a.name.endsWith('.apk')).toList();
  for (final abi in supportedAbis) {
    for (final asset in apks) {
      if (asset.name.endsWith('-$abi.apk')) return asset;
    }
  }
  for (final asset in apks) {
    if (asset.name.endsWith('-universal.apk')) return asset;
  }
  return null;
}
```

- [ ] **Step 4: Run the test again**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/updates/domain/asset_selector.dart \
        app/test/features/updates/asset_selector_test.dart
git commit -m "feat(updates): pick the apk that fits the device"
```

---

### Task 4: Downloading and verifying

**Files:**
- Create: `app/lib/features/updates/data/update_downloader.dart`
- Test: `app/test/features/updates/update_downloader_test.dart`

**Interfaces:** Produces

```dart
class UpdateDownloader {
  UpdateDownloader(Dio dio, {Future<Directory> Function()? directory});
  Future<File> download(ReleaseAsset asset, {void Function(double progress)? onProgress});
}
```

Throws `UpdateException(UpdateFailure.network)` when the transfer fails and
`UpdateException(UpdateFailure.malformed)` when the digest does not match,
deleting the file in both cases. `progress` runs from 0 to 1; when the
server sends no length it is reported as -1 (indeterminate).

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/updates/data/github_release_client.dart';
import 'package:nemo/features/updates/data/update_downloader.dart';
import 'package:nemo/features/updates/domain/app_release.dart';

/// Serves fixed bytes so the test never touches the network.
class _BytesAdapter implements HttpClientAdapter {
  _BytesAdapter(this.bytes, {this.fail = false});
  final List<int> bytes;
  final bool fail;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? s,
      Future<void>? c) async {
    if (fail) {
      throw DioException.connectionError(
          requestOptions: options, reason: 'offline');
    }
    return ResponseBody.fromBytes(bytes, 200,
        headers: {Headers.contentLengthHeader: ['${bytes.length}']});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  final payload = List<int>.generate(4096, (i) => i % 256);
  final digest = sha256.convert(payload).toString();
  late Directory dir;

  Dio dioWith(HttpClientAdapter adapter) => Dio()..httpClientAdapter = adapter;
  UpdateDownloader downloader(HttpClientAdapter adapter) =>
      UpdateDownloader(dioWith(adapter), directory: () async => dir);

  ReleaseAsset asset({String? sha}) => ReleaseAsset(
        name: 'nemo-0.2.0+2-arm64-v8a.apk',
        url: 'https://example.test/nemo.apk',
        size: 4096,
        sha256: sha,
      );

  setUp(() => dir = Directory.systemTemp.createTempSync('nemo-update'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('writes the file, reports progress and keeps it when the hash matches',
      () async {
    final seen = <double>[];
    final file = await downloader(_BytesAdapter(payload))
        .download(asset(sha: digest), onProgress: seen.add);

    expect(file.existsSync(), isTrue);
    expect(file.lengthSync(), payload.length);
    expect(file.path, endsWith('nemo-0.2.0+2-arm64-v8a.apk'));
    expect(seen, isNotEmpty);
    expect(seen.last, 1.0);
  });

  test('a wrong hash deletes the file and fails', () async {
    await expectLater(
      downloader(_BytesAdapter(payload)).download(asset(sha: 'deadbeef')),
      throwsA(isA<UpdateException>()
          .having((e) => e.failure, 'failure', UpdateFailure.malformed)),
    );
    expect(dir.listSync(), isEmpty, reason: 'nothing half-trusted is left');
  });

  test('an asset with no published hash is accepted', () async {
    final file = await downloader(_BytesAdapter(payload)).download(asset());
    expect(file.existsSync(), isTrue);
  });

  test('a failed transfer leaves nothing behind', () async {
    await expectLater(
      downloader(_BytesAdapter(payload, fail: true)).download(asset(sha: digest)),
      throwsA(isA<UpdateException>()
          .having((e) => e.failure, 'failure', UpdateFailure.network)),
    );
    expect(dir.listSync(), isEmpty);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `cd app && flutter test test/features/updates/update_downloader_test.dart`

- [ ] **Step 3: Implement**

```dart
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:nemo/features/updates/data/github_release_client.dart';
import 'package:nemo/features/updates/domain/app_release.dart';
import 'package:path_provider/path_provider.dart';

/// Downloads an update into the app's own cache directory, which needs no
/// permission and gets cleaned up by Android under pressure.
class UpdateDownloader {
  UpdateDownloader(this._dio, {Future<Directory> Function()? directory})
    : _directory = directory ?? getTemporaryDirectory;

  final Dio _dio;
  final Future<Directory> Function() _directory;

  Future<File> download(
    ReleaseAsset asset, {
    void Function(double progress)? onProgress,
  }) async {
    final file = File('${(await _directory()).path}/${asset.name}');
    if (file.existsSync()) file.deleteSync();
    try {
      await _dio.download(
        asset.url,
        file.path,
        onReceiveProgress: (received, total) =>
            onProgress?.call(total <= 0 ? -1 : received / total),
      );
    } on Object {
      if (file.existsSync()) file.deleteSync();
      throw const UpdateException(UpdateFailure.network);
    }

    final expected = asset.sha256;
    if (expected != null) {
      final actual = sha256.convert(await file.readAsBytes()).toString();
      if (actual != expected.toLowerCase()) {
        file.deleteSync();
        throw const UpdateException(UpdateFailure.malformed);
      }
    }
    onProgress?.call(1);
    return file;
  }
}
```

- [ ] **Step 4: Run the test again**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/updates/data/update_downloader.dart \
        app/test/features/updates/update_downloader_test.dart
git commit -m "feat(updates): download an update and check its hash"
```

---

### Task 5: Handing the file to Android

**Files:**
- Create: `app/lib/features/updates/data/apk_installer.dart`
- Modify: `app/android/app/src/main/AndroidManifest.xml` (add `REQUEST_INSTALL_PACKAGES`)
- Modify: `app/lib/core/providers.dart` (add `updatesSupportedProvider`)
- Test: `app/test/features/updates/apk_installer_test.dart`

**Interfaces:** Produces

```dart
abstract interface class ApkInstaller { Future<bool> install(File apk); }
class SystemApkInstaller implements ApkInstaller {
  SystemApkInstaller({Future<OpenResult> Function(String path)? open});
}
class UnsupportedApkInstaller implements ApkInstaller {}   // always false
final updatesSupportedProvider = Provider<bool>(...);      // Android only
```

`install` returns true when Android accepted the intent; the outcome of the
install itself belongs to the system dialog and is not reported back.

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/features/updates/data/apk_installer.dart';
import 'package:open_filex/open_filex.dart';

void main() {
  late File apk;

  setUp(() {
    apk = File('${Directory.systemTemp.createTempSync('nemo-apk').path}/n.apk')
      ..writeAsStringSync('not really an apk');
  });
  tearDown(() => apk.parent.deleteSync(recursive: true));

  test('hands the path to the system and reports acceptance', () async {
    final opened = <String>[];
    final installer = SystemApkInstaller(
      open: (path) async {
        opened.add(path);
        return OpenResult(type: ResultType.done, message: 'done');
      },
    );
    expect(await installer.install(apk), isTrue);
    expect(opened, [apk.path]);
  });

  test('reports a refusal rather than pretending it worked', () async {
    final installer = SystemApkInstaller(
      open: (_) async =>
          OpenResult(type: ResultType.permissionDenied, message: 'no'),
    );
    expect(await installer.install(apk), isFalse);
  });

  test('a missing file never reaches the system', () async {
    var called = false;
    final installer = SystemApkInstaller(open: (_) async {
      called = true;
      return OpenResult(type: ResultType.done, message: 'done');
    });
    apk.deleteSync();
    expect(await installer.install(apk), isFalse);
    expect(called, isFalse);
  });

  test('the unsupported installer does nothing', () async {
    expect(await const UnsupportedApkInstaller().install(apk), isFalse);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `cd app && flutter test test/features/updates/apk_installer_test.dart`

- [ ] **Step 3: Implement**

```dart
import 'dart:io';

import 'package:open_filex/open_filex.dart';

/// Opens an APK so Android can install it.
abstract interface class ApkInstaller {
  /// True when the system accepted the request. Whether the user then
  /// confirms the install is Android's business, not ours.
  Future<bool> install(File apk);
}

class SystemApkInstaller implements ApkInstaller {
  SystemApkInstaller({Future<OpenResult> Function(String path)? open})
    : _open = open ?? ((path) => OpenFilex.open(path));

  final Future<OpenResult> Function(String path) _open;

  @override
  Future<bool> install(File apk) async {
    if (!apk.existsSync()) return false;
    final result = await _open(apk.path);
    return result.type == ResultType.done;
  }
}

/// Everywhere that cannot install an APK, which is everywhere but Android.
class UnsupportedApkInstaller implements ApkInstaller {
  const UnsupportedApkInstaller();

  @override
  Future<bool> install(File apk) async => false;
}
```

Add to `app/lib/core/providers.dart`:

```dart
/// Only Android can install an APK, so only Android offers updates.
final updatesSupportedProvider = Provider<bool>(
  (_) => !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
);
```

Add to the manifest, beside the existing permissions:

```xml
    <!-- Needed to hand a downloaded APK to the system installer. Android
         still asks the user to allow installs from nemo the first time. -->
    <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>
```

- [ ] **Step 4: Run the test again**

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add app/lib/features/updates/data/apk_installer.dart app/lib/core/providers.dart \
        app/android/app/src/main/AndroidManifest.xml app/test/features/updates/apk_installer_test.dart
git commit -m "feat(updates): hand a downloaded apk to the system installer"
```

---

### Task 6: The controller

**Files:**
- Create: `app/lib/features/updates/ui/update_state.dart`
- Create: `app/lib/features/updates/ui/update_controller.dart`
- Modify: `app/lib/core/db/kv_store.dart` (add `lastUpdateCheck`, `dismissedUpdate`)
- Create: `app/test/support/fake_updates.dart`
- Test: `app/test/features/updates/update_controller_test.dart`

**Interfaces:** Produces

```dart
sealed class UpdateState {}
class UpdateIdle extends UpdateState {}
class UpdateChecking extends UpdateState {}
class UpToDate extends UpdateState { UpToDate(this.checkedAt); final DateTime checkedAt; }
class UpdateAvailable extends UpdateState { UpdateAvailable(this.release, this.asset); ... }
class UpdateDownloading extends UpdateState { UpdateDownloading(this.progress); final double progress; }
class UpdateReady extends UpdateState { UpdateReady(this.file, this.release); ... }
class UpdateFailed extends UpdateState { UpdateFailed(this.failure); final UpdateFailure failure; }

@Riverpod(keepAlive: true) class UpdateController extends _$UpdateController {
  UpdateState build();
  Future<void> check({bool manual = false});
  Future<void> download();
  Future<void> install();
  Future<void> dismiss();
}
final releaseClientProvider = Provider<GithubReleaseClient>(...);
final updateDownloaderProvider = Provider<UpdateDownloader>(...);
final apkInstallerProvider = Provider<ApkInstaller>(...);
final deviceAbisProvider = FutureProvider<List<String>>(...);
final currentVersionProvider = FutureProvider<AppVersion>(...);
```

Rules: an automatic `check` returns immediately when updates are
unsupported, when a check ran within 24 hours, or when the newest release is
the version the user dismissed. A failure during an automatic check leaves
`UpdateIdle`; during a manual one it sets `UpdateFailed`.

- [ ] **Step 1: Write the fakes**

```dart
// app/test/support/fake_updates.dart
import 'dart:io';

import 'package:nemo/features/updates/data/apk_installer.dart';
import 'package:nemo/features/updates/data/github_release_client.dart';
import 'package:nemo/features/updates/data/update_downloader.dart';
import 'package:nemo/features/updates/domain/app_release.dart';
import 'package:nemo/features/updates/domain/app_version.dart';

AppRelease releaseFixture({
  AppVersion version = const AppVersion(0, 2, 0),
  String notes = '- Faster search',
}) => AppRelease(
  version: version,
  tag: 'v$version',
  notes: notes,
  assets: [
    ReleaseAsset(
      name: 'nemo-$version+2-arm64-v8a.apk',
      url: 'https://example.test/arm64.apk',
      size: 24000000,
      sha256: 'abc123',
    ),
  ],
);

class FakeReleaseClient implements GithubReleaseClient {
  FakeReleaseClient({this.release, this.failure});
  AppRelease? release;
  UpdateFailure? failure;
  int calls = 0;

  @override
  String get repository => 'fake/repo';

  @override
  Future<AppRelease> latest() async {
    calls++;
    final f = failure;
    if (f != null) throw UpdateException(f);
    return release ?? releaseFixture();
  }
}

class FakeDownloader implements UpdateDownloader {
  FakeDownloader(this.file, {this.failure});
  final File file;
  UpdateFailure? failure;
  final progress = <double>[];

  @override
  Future<File> download(ReleaseAsset asset,
      {void Function(double progress)? onProgress}) async {
    final f = failure;
    if (f != null) throw UpdateException(f);
    for (final p in [0.5, 1.0]) {
      progress.add(p);
      onProgress?.call(p);
    }
    return file;
  }
}

class FakeInstaller implements ApkInstaller {
  final installed = <String>[];
  bool accepts = true;

  @override
  Future<bool> install(File apk) async {
    installed.add(apk.path);
    return accepts;
  }
}
```

- [ ] **Step 2: Write the failing controller test**

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/features/updates/data/github_release_client.dart';
import 'package:nemo/features/updates/domain/app_version.dart';
import 'package:nemo/features/updates/ui/update_controller.dart';
import 'package:nemo/features/updates/ui/update_state.dart';

import '../../support/fake_updates.dart';
import '../../support/test_db.dart';

void main() {
  late FakeReleaseClient client;
  late FakeDownloader downloader;
  late FakeInstaller installer;
  late File apk;
  late DateTime now;

  ProviderContainer container({bool supported = true}) {
    final db = testDatabase();
    addTearDown(db.close);
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        bootstrapProvider.overrideWithValue(
          const AppBootstrap(
            nodeId: 'test',
            hlcLast: null,
            themeMode: ThemeMode.system,
          ),
        ),
        nowProvider.overrideWithValue(() => now),
        updatesSupportedProvider.overrideWithValue(supported),
        currentVersionProvider.overrideWith((_) async => const AppVersion(0, 1, 0)),
        deviceAbisProvider.overrideWith((_) async => ['arm64-v8a']),
        releaseClientProvider.overrideWithValue(client),
        updateDownloaderProvider.overrideWithValue(downloader),
        apkInstallerProvider.overrideWithValue(installer),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() {
    now = DateTime(2026, 9, 8, 9);
    apk = File('${Directory.systemTemp.createTempSync('nemo-c').path}/n.apk')
      ..writeAsStringSync('apk');
    client = FakeReleaseClient();
    downloader = FakeDownloader(apk);
    installer = FakeInstaller();
  });
  tearDown(() => apk.parent.deleteSync(recursive: true));

  test('a newer release becomes available with its asset', () async {
    final c = container();
    await c.read(updateControllerProvider.notifier).check(manual: true);
    final state = c.read(updateControllerProvider);
    expect(state, isA<UpdateAvailable>());
    expect((state as UpdateAvailable).release.version, const AppVersion(0, 2, 0));
    expect(state.asset.name, endsWith('-arm64-v8a.apk'));
  });

  test('the running version or older means up to date', () async {
    client.release = releaseFixture(version: const AppVersion(0, 1, 0));
    final c = container();
    await c.read(updateControllerProvider.notifier).check(manual: true);
    expect(c.read(updateControllerProvider), isA<UpToDate>());
  });

  test('an automatic check is silent about failure, a manual one is not',
      () async {
    client.failure = UpdateFailure.network;
    final c = container();
    await c.read(updateControllerProvider.notifier).check();
    expect(c.read(updateControllerProvider), isA<UpdateIdle>());

    await c.read(updateControllerProvider.notifier).check(manual: true);
    expect(c.read(updateControllerProvider), isA<UpdateFailed>());
  });

  test('automatic checks run once a day, manual ones always', () async {
    final c = container();
    await c.read(updateControllerProvider.notifier).check();
    expect(client.calls, 1);

    now = now.add(const Duration(hours: 3));
    await c.read(updateControllerProvider.notifier).check();
    expect(client.calls, 1, reason: 'still inside the day');

    await c.read(updateControllerProvider.notifier).check(manual: true);
    expect(client.calls, 2, reason: 'asking directly always asks');

    now = now.add(const Duration(days: 1));
    await c.read(updateControllerProvider.notifier).check();
    expect(client.calls, 3);
  });

  test('a dismissed version stays dismissed until a newer one arrives',
      () async {
    final c = container();
    await c.read(updateControllerProvider.notifier).check(manual: true);
    await c.read(updateControllerProvider.notifier).dismiss();
    expect(c.read(updateControllerProvider), isA<UpdateIdle>());
    expect(await KvStore(c.read(appDatabaseProvider)).get(KvKeys.dismissedUpdate),
        '0.2.0');

    now = now.add(const Duration(days: 2));
    await c.read(updateControllerProvider.notifier).check();
    expect(c.read(updateControllerProvider), isA<UpdateIdle>());

    client.release = releaseFixture(version: const AppVersion(0, 3, 0));
    now = now.add(const Duration(days: 2));
    await c.read(updateControllerProvider.notifier).check();
    expect(c.read(updateControllerProvider), isA<UpdateAvailable>());
  });

  test('download reports progress then holds the file', () async {
    final c = container();
    await c.read(updateControllerProvider.notifier).check(manual: true);
    await c.read(updateControllerProvider.notifier).download();
    final state = c.read(updateControllerProvider);
    expect(state, isA<UpdateReady>());
    expect((state as UpdateReady).file.path, apk.path);
  });

  test('a broken download is reported and can be retried', () async {
    downloader.failure = UpdateFailure.malformed;
    final c = container();
    await c.read(updateControllerProvider.notifier).check(manual: true);
    await c.read(updateControllerProvider.notifier).download();
    expect(c.read(updateControllerProvider), isA<UpdateFailed>());
  });

  test('install hands the file over', () async {
    final c = container();
    await c.read(updateControllerProvider.notifier).check(manual: true);
    await c.read(updateControllerProvider.notifier).download();
    await c.read(updateControllerProvider.notifier).install();
    expect(installer.installed, [apk.path]);
  });

  test('where updates are unsupported nothing is asked', () async {
    final c = container(supported: false);
    await c.read(updateControllerProvider.notifier).check(manual: true);
    expect(client.calls, 0);
    expect(c.read(updateControllerProvider), isA<UpdateIdle>());
  });
}
```

- [ ] **Step 3: Run it and watch it fail**

Run: `cd app && flutter test test/features/updates/update_controller_test.dart`

- [ ] **Step 4: Add the two kv keys**

In `app/lib/core/db/kv_store.dart`, inside `KvKeys`:

```dart
  static const lastUpdateCheck = 'last_update_check';
  static const dismissedUpdate = 'dismissed_update';
```

- [ ] **Step 5: Implement the state**

```dart
// app/lib/features/updates/ui/update_state.dart
import 'dart:io';

import 'package:nemo/features/updates/data/github_release_client.dart';
import 'package:nemo/features/updates/domain/app_release.dart';

sealed class UpdateState {
  const UpdateState();
}

class UpdateIdle extends UpdateState {
  const UpdateIdle();
}

class UpdateChecking extends UpdateState {
  const UpdateChecking();
}

class UpToDate extends UpdateState {
  const UpToDate(this.checkedAt);
  final DateTime checkedAt;
}

class UpdateAvailable extends UpdateState {
  const UpdateAvailable(this.release, this.asset);
  final AppRelease release;
  final ReleaseAsset asset;
}

class UpdateDownloading extends UpdateState {
  const UpdateDownloading(this.progress);

  /// 0 to 1, or -1 when the server did not say how long the file is.
  final double progress;
}

class UpdateReady extends UpdateState {
  const UpdateReady(this.file, this.release);
  final File file;
  final AppRelease release;
}

class UpdateFailed extends UpdateState {
  const UpdateFailed(this.failure);
  final UpdateFailure failure;
}
```

- [ ] **Step 6: Implement the controller**

```dart
// app/lib/features/updates/ui/update_controller.dart
import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/db/kv_store.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/features/auth/ui/auth_controller.dart';
import 'package:nemo/features/updates/data/apk_installer.dart';
import 'package:nemo/features/updates/data/github_release_client.dart';
import 'package:nemo/features/updates/data/update_downloader.dart';
import 'package:nemo/features/updates/domain/app_version.dart';
import 'package:nemo/features/updates/domain/asset_selector.dart';
import 'package:nemo/features/updates/ui/update_state.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'update_controller.g.dart';

/// How long an automatic check waits before asking again.
const updateCheckInterval = Duration(hours: 24);

final releaseClientProvider = Provider<GithubReleaseClient>(
  (ref) => GithubReleaseClient(ref.watch(dioProvider)),
);

final updateDownloaderProvider = Provider<UpdateDownloader>(
  (ref) => UpdateDownloader(ref.watch(dioProvider)),
);

final apkInstallerProvider = Provider<ApkInstaller>(
  (ref) => ref.watch(updatesSupportedProvider)
      ? SystemApkInstaller()
      : const UnsupportedApkInstaller(),
);

final currentVersionProvider = FutureProvider<AppVersion>((_) async {
  final info = await PackageInfo.fromPlatform();
  return AppVersion.tryParse(info.version) ?? const AppVersion(0, 0, 0);
});

final deviceAbisProvider = FutureProvider<List<String>>((ref) async {
  if (!ref.watch(updatesSupportedProvider)) return const [];
  final android = await DeviceInfoPlugin().androidInfo;
  return android.supportedAbis;
});

@Riverpod(keepAlive: true)
class UpdateController extends _$UpdateController {
  @override
  UpdateState build() => const UpdateIdle();

  /// Looks for a newer release. An automatic check stays quiet: it obeys
  /// the daily interval, skips a version the user waved away, and says
  /// nothing when the network is not there.
  Future<void> check({bool manual = false}) async {
    if (!ref.read(updatesSupportedProvider)) return;
    final kv = ref.read(kvStoreProvider);
    final now = ref.read(nowProvider)();
    if (!manual && !await _dueForCheck(kv, now)) return;

    state = const UpdateChecking();
    try {
      final release = await ref.read(releaseClientProvider).latest();
      await kv.set(KvKeys.lastUpdateCheck, '${now.millisecondsSinceEpoch}');
      final current = await ref.read(currentVersionProvider.future);
      if (!release.version.isNewerThan(current)) {
        state = UpToDate(now);
        return;
      }
      if (!manual &&
          await kv.get(KvKeys.dismissedUpdate) == release.version.toString()) {
        state = const UpdateIdle();
        return;
      }
      final asset = selectAsset(
        release.assets,
        await ref.read(deviceAbisProvider.future),
      );
      state = asset == null
          ? const UpdateFailed(UpdateFailure.notFound)
          : UpdateAvailable(release, asset);
    } on UpdateException catch (e) {
      state = manual ? UpdateFailed(e.failure) : const UpdateIdle();
    }
  }

  Future<bool> _dueForCheck(KvStore kv, DateTime now) async {
    final raw = await kv.get(KvKeys.lastUpdateCheck);
    final last = int.tryParse(raw ?? '');
    if (last == null) return true;
    final since = now.difference(DateTime.fromMillisecondsSinceEpoch(last));
    return since >= updateCheckInterval;
  }

  Future<void> download() async {
    final available = state;
    if (available is! UpdateAvailable) return;
    state = const UpdateDownloading(0);
    try {
      final file = await ref
          .read(updateDownloaderProvider)
          .download(
            available.asset,
            onProgress: (p) => state = UpdateDownloading(p),
          );
      state = UpdateReady(file, available.release);
    } on UpdateException catch (e) {
      state = UpdateFailed(e.failure);
    }
  }

  Future<void> install() async {
    final ready = state;
    if (ready is! UpdateReady) return;
    await ref.read(apkInstallerProvider).install(ready.file);
  }

  /// Stops this version from asking again. A newer one still will.
  Future<void> dismiss() async {
    final current = state;
    if (current is UpdateAvailable) {
      await ref
          .read(kvStoreProvider)
          .set(KvKeys.dismissedUpdate, current.release.version.toString());
    }
    state = const UpdateIdle();
  }
}
```

- [ ] **Step 7: Generate, run, commit**

```bash
cd app && dart run build_runner build && dart format lib test
flutter test test/features/updates/
git add app/lib/features/updates app/lib/core/db/kv_store.dart app/test
git commit -m "feat(updates): the update state machine"
```

---

### Task 7: Showing it to the user

**Files:**
- Create: `app/lib/features/updates/ui/update_tile.dart`
- Create: `app/lib/features/updates/ui/update_banner.dart`
- Modify: `app/lib/features/settings/ui/settings_screen.dart`
- Modify: `app/lib/features/tasks/ui/today_screen.dart`
- Modify: `app/lib/app.dart`
- Modify: `app/lib/l10n/app_en.arb`, `app_de.arb`, `app_it.arb`
- Test: `app/test/features/updates/update_ui_test.dart`

**Interfaces:** Consumes `updateControllerProvider`, `UpdateState` and
`currentVersionProvider` from Task 6. Produces `UpdateTile` and
`UpdateBanner`, both returning `SizedBox.shrink()` when
`updatesSupportedProvider` is false.

- [ ] **Step 1: Add the strings**

To `app_en.arb` (then the same keys in `app_de.arb` and `app_it.arb`):

```json
  "updatesTitle": "Updates",
  "updatesCurrentVersion": "You have version {version}",
  "@updatesCurrentVersion": {"placeholders": {"version": {"type": "String"}}},
  "updatesCheckNow": "Check for updates",
  "updatesChecking": "Checking…",
  "updatesUpToDate": "nemo is up to date",
  "updatesAvailable": "Version {version} is available",
  "@updatesAvailable": {"placeholders": {"version": {"type": "String"}}},
  "updatesWhatsNew": "What's new",
  "updatesDownload": "Download",
  "updatesDownloading": "Downloading… {percent}%",
  "@updatesDownloading": {"placeholders": {"percent": {"type": "int"}}},
  "updatesInstall": "Install",
  "updatesInstallHint": "Android will ask you to confirm the install.",
  "updatesLater": "Later",
  "updatesErrorNetwork": "Could not reach GitHub.",
  "updatesErrorRateLimited": "GitHub is rate limiting; try again later.",
  "updatesErrorNotFound": "No download for this device in that release.",
  "updatesErrorMalformed": "That download did not match its checksum.",
```

German: `Aktualisierungen`, `Du hast Version {version}`, `Nach Updates
suchen`, `Suche …`, `nemo ist aktuell`, `Version {version} ist verfügbar`,
`Neu`, `Herunterladen`, `Lädt … {percent} %`, `Installieren`, `Android
fragt dich, ob du die Installation erlaubst.`, `Später`, `GitHub ist nicht
erreichbar.`, `GitHub bremst die Anfragen; versuche es später erneut.`,
`In dieser Version gibt es keinen Download für dieses Gerät.`, `Der
Download passt nicht zu seiner Prüfsumme.`

Italian: `Aggiornamenti`, `Hai la versione {version}`, `Cerca
aggiornamenti`, `Controllo…`, `nemo è aggiornato`, `La versione {version} è
disponibile`, `Novità`, `Scarica`, `Download… {percent}%`, `Installa`,
`Android ti chiederà di confermare l'installazione.`, `Più tardi`,
`Impossibile raggiungere GitHub.`, `GitHub sta limitando le richieste;
riprova più tardi.`, `Nessun download per questo dispositivo in quella
versione.`, `Il download non corrisponde alla sua checksum.`

Then `flutter gen-l10n`.

- [ ] **Step 2: Write the failing widget test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/features/updates/data/github_release_client.dart';
import 'package:nemo/features/updates/domain/app_version.dart';
import 'package:nemo/features/updates/ui/update_controller.dart';
import 'package:nemo/router.dart';

import '../../support/fake_updates.dart';
import '../../support/pump_app.dart';

void main() {
  late FakeReleaseClient client;
  late FakeInstaller installer;

  List<Object> overrides({bool supported = true}) => [
        updatesSupportedProvider.overrideWithValue(supported),
        currentVersionProvider.overrideWith((_) async => const AppVersion(0, 1, 0)),
        deviceAbisProvider.overrideWith((_) async => ['arm64-v8a']),
        releaseClientProvider.overrideWithValue(client),
        apkInstallerProvider.overrideWithValue(installer),
      ];

  setUp(() {
    client = FakeReleaseClient();
    installer = FakeInstaller();
  });

  appTest('settings offers a check and reports the result', (tester) async {
    await pumpApp(tester,
        initialLocation: Routes.settings, overrides: overrides());
    expect(find.text('Updates'), findsOneWidget);
    expect(find.textContaining('You have version 0.1.0'), findsOneWidget);

    await tester.tap(find.byKey(const Key('check-for-updates')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Version 0.2.0 is available'), findsOneWidget);
  });

  appTest('a failure names itself when you asked for it', (tester) async {
    client.failure = UpdateFailure.rateLimited;
    await pumpApp(tester,
        initialLocation: Routes.settings, overrides: overrides());
    await tester.tap(find.byKey(const Key('check-for-updates')));
    await tester.pumpAndSettle();
    expect(find.textContaining('rate limiting'), findsOneWidget);
  });

  appTest('the banner appears on Today and can be waved away', (tester) async {
    final app = await pumpApp(tester, overrides: overrides());
    await app.container.read(updateControllerProvider.notifier).check(manual: true);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('update-banner')), findsOneWidget);

    await tester.tap(find.byKey(const Key('update-banner-dismiss')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('update-banner')), findsNothing);
  });

  appTest('nothing shows where updates are unsupported', (tester) async {
    await pumpApp(tester,
        initialLocation: Routes.settings,
        overrides: overrides(supported: false));
    expect(find.text('Updates'), findsNothing);
  });
}
```

- [ ] **Step 3: Run it and watch it fail**

Run: `cd app && flutter test test/features/updates/update_ui_test.dart`

- [ ] **Step 4: Build the tile**

```dart
// app/lib/features/updates/ui/update_tile.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nemo/core/providers.dart';
import 'package:nemo/core/widgets/section_header.dart';
import 'package:nemo/features/updates/data/github_release_client.dart';
import 'package:nemo/features/updates/ui/update_controller.dart';
import 'package:nemo/features/updates/ui/update_state.dart';
import 'package:nemo/l10n/app_localizations.dart';

/// The Settings entry: which version is running, and one action for
/// whatever the updater is doing.
class UpdateTile extends ConsumerWidget {
  const UpdateTile({super.key});

  String _errorText(L l, UpdateFailure failure) => switch (failure) {
    UpdateFailure.network => l.updatesErrorNetwork,
    UpdateFailure.rateLimited => l.updatesErrorRateLimited,
    UpdateFailure.notFound => l.updatesErrorNotFound,
    UpdateFailure.malformed => l.updatesErrorMalformed,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(updatesSupportedProvider)) return const SizedBox.shrink();
    final l = L.of(context);
    final scheme = Theme.of(context).colorScheme;
    final state = ref.watch(updateControllerProvider);
    final notifier = ref.read(updateControllerProvider.notifier);
    final version = ref.watch(currentVersionProvider).value;

    final (String subtitle, Color subtitleColor) = switch (state) {
      UpdateChecking() => (l.updatesChecking, scheme.onSurfaceVariant),
      UpToDate() => (l.updatesUpToDate, scheme.onSurfaceVariant),
      UpdateAvailable(:final release) => (
        l.updatesAvailable(release.version.toString()),
        scheme.primary,
      ),
      UpdateDownloading(:final progress) => (
        l.updatesDownloading(progress < 0 ? 0 : (progress * 100).round()),
        scheme.onSurfaceVariant,
      ),
      UpdateReady() => (l.updatesInstallHint, scheme.onSurfaceVariant),
      UpdateFailed(:final failure) => (_errorText(l, failure), scheme.error),
      UpdateIdle() => (
        version == null
            ? l.updatesCheckNow
            : l.updatesCurrentVersion(version.toString()),
        scheme.onSurfaceVariant,
      ),
    };

    final Widget trailing = switch (state) {
      UpdateChecking() => const SizedBox.square(
        dimension: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      UpdateDownloading(:final progress) => SizedBox.square(
        dimension: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          value: progress < 0 ? null : progress,
        ),
      ),
      UpdateAvailable() => FilledButton(
        key: const Key('download-update'),
        onPressed: notifier.download,
        child: Text(l.updatesDownload),
      ),
      UpdateReady() => FilledButton(
        key: const Key('install-update'),
        onPressed: notifier.install,
        child: Text(l.updatesInstall),
      ),
      _ => IconButton(
        key: const Key('check-for-updates'),
        tooltip: l.updatesCheckNow,
        icon: const Icon(Icons.refresh_rounded),
        onPressed: () => notifier.check(manual: true),
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: l.updatesTitle),
        ListTile(
          leading: const Icon(Icons.system_update_alt_rounded),
          title: Text(
            version == null
                ? l.updatesTitle
                : l.updatesCurrentVersion(version.toString()),
          ),
          subtitle: Text(subtitle, style: TextStyle(color: subtitleColor)),
          trailing: trailing,
        ),
        if (state is UpdateAvailable && state.release.notes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.updatesWhatsNew,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  state.release.notes,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 5: Build the banner**

```dart
// app/lib/features/updates/ui/update_banner.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nemo/features/updates/ui/update_controller.dart';
import 'package:nemo/features/updates/ui/update_state.dart';
import 'package:nemo/l10n/app_localizations.dart';
import 'package:nemo/router.dart';

/// One line above the task list, and only when there is genuinely a newer
/// version. Dismissing it silences that version, not the next one.
class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updateControllerProvider);
    if (state is! UpdateAvailable) return const SizedBox.shrink();
    final l = L.of(context);
    final scheme = Theme.of(context).colorScheme;

    return Material(
      key: const Key('update-banner'),
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Icon(Icons.system_update_alt_rounded, size: 20, color: scheme.onPrimaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l.updatesAvailable(state.release.version.toString()),
                style: TextStyle(color: scheme.onPrimaryContainer),
              ),
            ),
            TextButton(
              onPressed: () => context.push(Routes.settings),
              child: Text(l.updatesDownload),
            ),
            IconButton(
              key: const Key('update-banner-dismiss'),
              tooltip: l.updatesLater,
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: ref.read(updateControllerProvider.notifier).dismiss,
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Wire them in**

In `settings_screen.dart`, add `const UpdateTile()` between the appearance
section and `SyncSettingsSection`. In `today_screen.dart`, wrap the body:

```dart
      body: Column(
        children: [
          const UpdateBanner(),
          Expanded(child: AsyncBody(value: tasks, data: (items) { /* unchanged */ })),
        ],
      ),
```

In `app.dart`, extend the existing post-frame callback:

```dart
      await ref.read(authControllerProvider.notifier).restore();
      if (!mounted) return;
      ref.read(syncEngineProvider.notifier).requestSync(
            delay: const Duration(milliseconds: 200),
          );
      // Quiet unless something is actually newer, and at most daily.
      unawaited(ref.read(updateControllerProvider.notifier).check());
```

- [ ] **Step 7: Run the tests, then the whole suite**

```bash
cd app && dart format lib test && flutter analyze
flutter test -j 2 --exclude-tags design
dart run ../tool/check_coverage.dart 80
```

- [ ] **Step 8: Commit**

```bash
git add app/lib app/test
git commit -m "feat(updates): offer the update in settings and on today"
```

---

### Task 8: Publishing a release from a tag

**Files:**
- Create: `.github/workflows/release.yml`
- Create: `CHANGELOG.md`
- Modify: `README.md`

**Interfaces:** Consumes the four secrets from Task 0. Produces GitHub
releases whose assets are named `nemo-<version>+<build>-<abi>.apk` and
`nemo-<version>+<build>-universal.apk`, which Task 3 already knows how to
read.

- [ ] **Step 1: Start the changelog**

```markdown
# Changelog

## 0.1.0 — 2026-09-07

- First release: offline lists, tasks, subtasks, due dates and reminders,
  tags and priorities, search, and optional sync with a self-hosted server.
```

- [ ] **Step 2: Write the workflow**

```yaml
name: Release

on:
  push:
    tags: ['v*']

env:
  FLUTTER_VERSION: '3.47.2'

jobs:
  release:
    name: Build, sign and publish
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v5

      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          flutter-version: ${{ env.FLUTTER_VERSION }}

      - uses: actions/setup-java@v5
        with:
          distribution: temurin
          java-version: '17'

      # A tag that disagrees with the pubspec would ship a build whose
      # in-app version does not match the release the app compares against.
      - name: Check the tag against the pubspec
        run: |
          tag="${GITHUB_REF_NAME#v}"
          pubspec=$(grep '^version:' app/pubspec.yaml | awk '{print $2}')
          if [ "$tag" != "${pubspec%%+*}" ]; then
            echo "::error::tag $GITHUB_REF_NAME does not match pubspec $pubspec"
            exit 1
          fi
          echo "version=$pubspec" >> "$GITHUB_ENV"

      - name: Take the notes from the changelog
        run: |
          version="${GITHUB_REF_NAME#v}"
          awk -v v="$version" '
            $0 ~ "^## " v { found = 1; next }
            found && /^## / { exit }
            found { print }
          ' CHANGELOG.md > release-notes.md
          if [ ! -s release-notes.md ]; then
            echo "::error::CHANGELOG.md has no section for $version"
            exit 1
          fi
          cat release-notes.md

      - run: flutter pub get

      - name: Configure signing
        env:
          KEYSTORE: ${{ secrets.ANDROID_KEYSTORE_BASE64 }}
          STORE_PASSWORD: ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
          KEY_ALIAS: ${{ secrets.ANDROID_KEY_ALIAS }}
          KEY_PASSWORD: ${{ secrets.ANDROID_KEY_PASSWORD }}
        run: |
          if [ -z "$KEYSTORE" ]; then
            echo "::error::no signing key; a debug-signed release cannot update anything"
            exit 1
          fi
          echo "$KEYSTORE" | base64 -d > app/android/nemo.jks
          cat > app/android/key.properties <<PROPS
          storeFile=nemo.jks
          storePassword=$STORE_PASSWORD
          keyAlias=$KEY_ALIAS
          keyPassword=$KEY_PASSWORD
          PROPS

      - name: Build the APKs
        working-directory: app
        run: |
          flutter build apk --release
          flutter build apk --release --split-per-abi

      - name: Confirm they carry the release key
        run: |
          "$ANDROID_HOME"/build-tools/*/apksigner verify --print-certs \
            app/build/app/outputs/release/nemo-*-arm64-v8a.apk | grep -q "CN=nemo" \
            || { echo "::error::the release is not signed with nemo's key"; exit 1; }

      - name: Publish
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          gh release create "$GITHUB_REF_NAME" \
            --title "nemo $GITHUB_REF_NAME" \
            --notes-file release-notes.md \
            app/build/app/outputs/release/*.apk
```

The universal build runs first so that the split build's `Sync` task leaves
all four files in `outputs/release`.

- [ ] **Step 3: Document releasing**

Add to `README.md` under the Android section: bump `version:` in
`app/pubspec.yaml` (both the version and the build number), add the
matching `CHANGELOG.md` section, then

```bash
git tag v0.2.0 && git push origin v0.2.0
```

and note that the app checks GitHub once a day, that the first install after
switching to the release key needs the old debug-signed nemo uninstalled,
and that Android will ask for permission to install apps from nemo the first
time.

- [ ] **Step 4: Rehearse the workflow without publishing**

```bash
act -n -W .github/workflows/release.yml 2>/dev/null || \
  echo "no act available; review the workflow by eye and rely on the first real tag"
```

Then verify the changelog extraction on its own, which is the part most
likely to be wrong:

```bash
awk -v v="0.1.0" '$0 ~ "^## " v {found=1; next} found && /^## / {exit} found {print}' CHANGELOG.md
```

Expected: the bullet list for 0.1.0, nothing else.

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/release.yml CHANGELOG.md README.md
git commit -m "ci: publish a signed release when a v tag is pushed"
```

---

### Task 9: The first real release, end to end

**Files:** none; this is the acceptance test for everything above.

- [ ] **Step 1: Bump and tag**

Set `version: 0.2.0+2` in `app/pubspec.yaml`, add the `## 0.2.0` section to
`CHANGELOG.md`, commit, then `git tag v0.2.0 && git push origin v0.2.0`.

- [ ] **Step 2: Watch the workflow**

```bash
gh run watch --exit-status
gh release view v0.2.0
```

Expected: four APKs attached, notes matching the changelog.

- [ ] **Step 3: Confirm the app sees it**

```bash
curl -s https://api.github.com/repos/13/nemo_todo/releases/latest \
  | python3 -c "import sys,json; d=json.load(sys.stdin); \
print(d['tag_name'], [a['name'] for a in d['assets']], \
[a.get('digest') for a in d['assets']][:1])"
```

Expected: `v0.2.0`, the four names, and a `sha256:` digest.

- [ ] **Step 4: Manual QA on a device**

Install the 0.1.0 build signed with the release key, open Settings, check for
updates, download, install, and confirm the app reopens as 0.2.0 with its
tasks intact. This is the one part no test here covers, because the install
dialog belongs to Android.

- [ ] **Step 5: Final gate**

```bash
export PATH="$HOME/flutter/bin:$PATH"
flutter analyze
dart format --output=none --set-exit-if-changed \
  packages/nemo_core/lib packages/nemo_core/test server/lib server/bin \
  server/test app/lib app/test tool
(cd packages/nemo_core && dart test)
(cd server && dart test)
(cd app && flutter test -j 2 --coverage --exclude-tags design \
  && dart run ../tool/check_coverage.dart 80)
```

---

## Risks

- **The keystore is the feature.** Lose it and every installed nemo is
  stranded on its current version. Task 0 step 5 exists for that reason.
- **`open_filex`'s FileProvider** must expose the cache directory. Its
  `file_paths.xml` declares `cache-path`, which is where
  `getTemporaryDirectory()` points on Android, so this should hold; if an
  install ever fails with a `FileUriExposedException`, replace
  `SystemApkInstaller` with a small `FileProvider` of our own plus
  `android_intent_plus`, changing nothing outside that one class.
- **Anonymous rate limit** is 60 requests per hour per address. A daily
  check per device is far under it, and a rate-limited answer is handled.
- **The debug-signed APKs already handed out** cannot be updated in place.
  Anyone holding one uninstalls once, losing local tasks unless they have
  synced.
