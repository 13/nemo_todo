# Checkmark Logo Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace nemo's clownfish mark with a teal disc that has a rounded check cut out of it, everywhere the mark appears.

**Architecture:** The mark is one even-odd path on a 512 canvas: a disc, then the outline of a rounded check stroke that becomes a hole. The SVG masters in `assets/logo` carry that path, and `tool/generate_icons.sh` renders every Android and web PNG from them. `NemoMark` paints the same path command for command, so the app never loads an image.

**Tech Stack:** SVG, librsvg (`rsvg-convert`), ImageMagick (`magick`), Flutter `CustomPainter`, flutter_test.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-09-13-check-logo-design.md`. Read it before Task 1.
- Work in the worktree `/home/ben/repo/nemo_todo-logo` on branch `feat/check-logo`. Start only after the photos-on-tasks branch has finished. If `main` has moved by then, run `git rebase main` first.
- Brand colours unchanged: mark `#0E7C86`, tile gradient `#13949F` → `#0A5C66`; the dark wordmark's mark stays `#5BC0C9` on `#0E1616`.
- Canvas 512 × 512. Disc: centre (256, 256), radius 200. Check half-width 31.5.
- Mark path, verbatim, `fill-rule="evenodd"`:
  `M 56 256 A 200 200 0 1 0 456 256 A 200 200 0 1 0 56 256 Z M 127.87 265.42 L 206.87 343.42 A 31.5 31.5 0 0 0 251.10 343.45 L 381.10 215.45 A 31.5 31.5 0 0 0 381.45 170.90 A 31.5 31.5 0 0 0 336.90 170.55 L 229.03 276.76 L 172.13 220.58 A 31.5 31.5 0 0 0 127.58 220.87 A 31.5 31.5 0 0 0 127.87 265.42 Z`
- Placements: icon tile `s = 0.76`; maskable `s = 0.66`; adaptive foreground `s = 0.6`; notification `translate(-25.6 -25.6) scale(1.1)`; wordmarks `translate(49 61) scale(0.375)`. A scale `s` about the centre is `translate(256·(1−s) 256·(1−s)) scale(s)`.
- `NemoLogoTile` sizes its mark `size * 0.76`.
- `logo.png` in the photos checkout is reference only: never commit, move or delete it.
- Flutter is not on the default PATH. Prefix every `flutter`/`dart` command with `export PATH=$HOME/fvm/versions/3.47.2/bin:$PATH`. The root `pubspec.yaml` is a pub workspace: never create a standalone pubspec or commit a per-package lockfile.
- CI runs `flutter analyze` from the repo root and fails on info-level lints. `very_good_analysis`; prefer `const`, trailing commas, comments that explain why.
- Commit messages use Conventional Commits and end with:

```
Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01KTnpjror3f9jBTwWnhzGse
```

## File Structure

**Modified**

| Path | Change |
|---|---|
| `assets/logo/nemo-mark.svg` | The mark, teal |
| `assets/logo/nemo-mark-white.svg` | The mark, white |
| `assets/logo/nemo-icon.svg` | The mark on the rounded gradient tile |
| `assets/logo/nemo-icon-maskable.svg` | The mark on the full-bleed gradient |
| `assets/logo/nemo-adaptive-foreground.svg` | The mark alone, inside the safe zone |
| `assets/logo/nemo-notification.svg` | The status bar silhouette |
| `assets/logo/nemo-wordmark.svg`, `nemo-wordmark-dark.svg` | The mark beside the unchanged lettering |
| `tool/generate_icons.sh` | Requires ImageMagick; strips and recompresses every PNG it writes |
| `app/android/app/src/main/res/{mipmap,drawable}-*/*.png`, `app/web/favicon.png`, `app/web/icons/*.png` | Regenerated |
| `app/lib/core/widgets/nemo_mark.dart` | Painter draws the checkmark; tile mark at 0.76 |
| `app/test/core/widgets/nemo_mark_test.dart` | Pixel test of the mark's shape; tile proportion |
| `README.md` | "The logo" describes the checkmark |
| `CHANGELOG.md` | An Unreleased "Changed" entry |

`nemo-adaptive-background.svg`, the adaptive icon XML (whose monochrome layer reuses `ic_launcher_foreground`), the splash XML and the theme are not touched.

---

### Task 1: The mark in the masters and the rendered icons

**Files:**
- Modify: `assets/logo/nemo-mark.svg`, `assets/logo/nemo-mark-white.svg`, `assets/logo/nemo-icon.svg`, `assets/logo/nemo-icon-maskable.svg`, `assets/logo/nemo-adaptive-foreground.svg`, `assets/logo/nemo-notification.svg`, `assets/logo/nemo-wordmark.svg`, `assets/logo/nemo-wordmark-dark.svg`
- Modify: `tool/generate_icons.sh`
- Modify (regenerated): every PNG listed in `tool/check_icons.sh`
- Modify: `README.md` (the `generate_icons.sh` comment line only)

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: `assets/logo/nemo-mark.svg` containing the exact mark path from Global Constraints. Task 2's painter mirrors it.

- [ ] **Step 1: Write the failing check**

The check for this task is the absence of the old fish and the presence of the new mark in every master that carries one. Run it before any change:

```bash
cd /home/ben/repo/nemo_todo-logo
grep -l 'M 73 256 C 79 196' assets/logo/*.svg
grep -L 'M 56 256 A 200 200 0 1 0 456 256' assets/logo/nemo-mark.svg assets/logo/nemo-mark-white.svg assets/logo/nemo-icon.svg assets/logo/nemo-icon-maskable.svg assets/logo/nemo-adaptive-foreground.svg assets/logo/nemo-notification.svg assets/logo/nemo-wordmark.svg assets/logo/nemo-wordmark-dark.svg
```

Expected: the first command lists all eight files, meaning the fish is still there. The second also lists all eight, meaning none carries the mark yet. Both must print nothing once the task is done.

- [ ] **Step 2: Write `assets/logo/nemo-mark.svg`**

Replace the whole file with:

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512" role="img" aria-label="nemo"><path d="M 56 256 A 200 200 0 1 0 456 256 A 200 200 0 1 0 56 256 Z M 127.87 265.42 L 206.87 343.42 A 31.5 31.5 0 0 0 251.10 343.45 L 381.10 215.45 A 31.5 31.5 0 0 0 381.45 170.90 A 31.5 31.5 0 0 0 336.90 170.55 L 229.03 276.76 L 172.13 220.58 A 31.5 31.5 0 0 0 127.58 220.87 A 31.5 31.5 0 0 0 127.87 265.42 Z" fill="#0E7C86" fill-rule="evenodd"/></svg>
```

- [ ] **Step 3: Write `assets/logo/nemo-mark-white.svg`**

Replace the whole file with:

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512" role="img" aria-label="nemo"><path d="M 56 256 A 200 200 0 1 0 456 256 A 200 200 0 1 0 56 256 Z M 127.87 265.42 L 206.87 343.42 A 31.5 31.5 0 0 0 251.10 343.45 L 381.10 215.45 A 31.5 31.5 0 0 0 381.45 170.90 A 31.5 31.5 0 0 0 336.90 170.55 L 229.03 276.76 L 172.13 220.58 A 31.5 31.5 0 0 0 127.58 220.87 A 31.5 31.5 0 0 0 127.87 265.42 Z" fill="#FFFFFF" fill-rule="evenodd"/></svg>
```

- [ ] **Step 4: Write `assets/logo/nemo-icon.svg`**

Replace the whole file with the following. The mark is at `s = 0.76`, so the translate is 256 × 0.24 = 61.44.

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512" role="img" aria-label="nemo"><defs><linearGradient id="tile" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#13949F"/><stop offset="1" stop-color="#0A5C66"/></linearGradient></defs><rect width="512" height="512" rx="116" fill="url(#tile)"/><g transform="translate(61.44 61.44) scale(0.76)"><path d="M 56 256 A 200 200 0 1 0 456 256 A 200 200 0 1 0 56 256 Z M 127.87 265.42 L 206.87 343.42 A 31.5 31.5 0 0 0 251.10 343.45 L 381.10 215.45 A 31.5 31.5 0 0 0 381.45 170.90 A 31.5 31.5 0 0 0 336.90 170.55 L 229.03 276.76 L 172.13 220.58 A 31.5 31.5 0 0 0 127.58 220.87 A 31.5 31.5 0 0 0 127.87 265.42 Z" fill="#FFFFFF" fill-rule="evenodd"/></g></svg>
```

- [ ] **Step 5: Write `assets/logo/nemo-icon-maskable.svg`**

Replace the whole file with the following. The mark is at `s = 0.66`, so the translate is 256 × 0.34 = 87.04.

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512" role="img" aria-label="nemo"><defs><linearGradient id="tile" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#13949F"/><stop offset="1" stop-color="#0A5C66"/></linearGradient></defs><rect width="512" height="512" fill="url(#tile)"/><g transform="translate(87.04 87.04) scale(0.66)"><path d="M 56 256 A 200 200 0 1 0 456 256 A 200 200 0 1 0 56 256 Z M 127.87 265.42 L 206.87 343.42 A 31.5 31.5 0 0 0 251.10 343.45 L 381.10 215.45 A 31.5 31.5 0 0 0 381.45 170.90 A 31.5 31.5 0 0 0 336.90 170.55 L 229.03 276.76 L 172.13 220.58 A 31.5 31.5 0 0 0 127.58 220.87 A 31.5 31.5 0 0 0 127.87 265.42 Z" fill="#FFFFFF" fill-rule="evenodd"/></g></svg>
```

- [ ] **Step 6: Write `assets/logo/nemo-adaptive-foreground.svg`**

Replace the whole file with the following. The mark is at `s = 0.6`, so the translate is 256 × 0.4 = 102.40.

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512" role="img" aria-label="nemo"><g transform="translate(102.40 102.40) scale(0.6)"><path d="M 56 256 A 200 200 0 1 0 456 256 A 200 200 0 1 0 56 256 Z M 127.87 265.42 L 206.87 343.42 A 31.5 31.5 0 0 0 251.10 343.45 L 381.10 215.45 A 31.5 31.5 0 0 0 381.45 170.90 A 31.5 31.5 0 0 0 336.90 170.55 L 229.03 276.76 L 172.13 220.58 A 31.5 31.5 0 0 0 127.58 220.87 A 31.5 31.5 0 0 0 127.87 265.42 Z" fill="#FFFFFF" fill-rule="evenodd"/></g></svg>
```

- [ ] **Step 7: Write `assets/logo/nemo-notification.svg`**

Replace the whole file with:

```svg
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" width="512" height="512" role="img" aria-label="nemo"><g transform="translate(-25.6 -25.6) scale(1.1)"><path d="M 56 256 A 200 200 0 1 0 456 256 A 200 200 0 1 0 56 256 Z M 127.87 265.42 L 206.87 343.42 A 31.5 31.5 0 0 0 251.10 343.45 L 381.10 215.45 A 31.5 31.5 0 0 0 381.45 170.90 A 31.5 31.5 0 0 0 336.90 170.55 L 229.03 276.76 L 172.13 220.58 A 31.5 31.5 0 0 0 127.58 220.87 A 31.5 31.5 0 0 0 127.87 265.42 Z" fill="#FFFFFF" fill-rule="evenodd"/></g></svg>
```

- [ ] **Step 8: Put the mark in both wordmarks**

`nemo-wordmark.svg` and `nemo-wordmark-dark.svg` share the same structure, and each needs the same two edits. Leave the `<rect>`, the `fill` values and the lettering path (`id="text1"`) as they are.

In each file, replace the line

```
     transform="translate(-11.11 2.76) scale(0.526935)"
```

with

```
     transform="translate(49 61) scale(0.375)"
```

Then, in the `<path>` with `id="path1"`, replace the whole `d="M 73 256 C 79 196 … 115 234 Z"` attribute (the old fish, one line) with:

```
       d="M 56 256 A 200 200 0 1 0 456 256 A 200 200 0 1 0 56 256 Z M 127.87 265.42 L 206.87 343.42 A 31.5 31.5 0 0 0 251.10 343.45 L 381.10 215.45 A 31.5 31.5 0 0 0 381.45 170.90 A 31.5 31.5 0 0 0 336.90 170.55 L 229.03 276.76 L 172.13 220.58 A 31.5 31.5 0 0 0 127.58 220.87 A 31.5 31.5 0 0 0 127.87 265.42 Z"
```

- [ ] **Step 9: Run the check to verify it passes**

```bash
cd /home/ben/repo/nemo_todo-logo
grep -l 'M 73 256 C 79 196' assets/logo/*.svg
grep -L 'M 56 256 A 200 200 0 1 0 456 256' assets/logo/nemo-mark.svg assets/logo/nemo-mark-white.svg assets/logo/nemo-icon.svg assets/logo/nemo-icon-maskable.svg assets/logo/nemo-adaptive-foreground.svg assets/logo/nemo-notification.svg assets/logo/nemo-wordmark.svg assets/logo/nemo-wordmark-dark.svg
for f in assets/logo/*.svg; do rsvg-convert -w 64 -h 64 "$f" -o /dev/null || echo "does not render: $f"; done
```

Expected: no output from any of the three commands.

- [ ] **Step 10: Make the generator strip and recompress what it renders**

Replace `tool/generate_icons.sh` with:

```bash
#!/usr/bin/env bash
# Renders every launcher and web icon from the SVG masters in assets/logo.
# Needs rsvg-convert (librsvg) and magick (ImageMagick). Run from anywhere:
#   tool/generate_icons.sh
set -euo pipefail
cd "$(dirname "$0")/.."

LOGO=assets/logo
RES=app/android/app/src/main/res
WEB=app/web

command -v rsvg-convert > /dev/null || {
  echo "rsvg-convert not found; install librsvg" >&2
  exit 1
}
command -v magick > /dev/null || {
  echo "magick not found; install ImageMagick" >&2
  exit 1
}

# rsvg-convert writes creation metadata and a middling compression level;
# neither does anything for an icon but add bytes to every build.
render() {
  rsvg-convert -w "$2" -h "$2" "$1" -o "$3"
  magick "$3" -strip -define png:compression-level=9 "$3"
}

# Android legacy launcher icon, one per density.
for entry in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
  density=${entry%%:*}; size=${entry##*:}
  mkdir -p "$RES/mipmap-$density"
  render "$LOGO/nemo-icon.svg" "$size" "$RES/mipmap-$density/ic_launcher.png"
done

# Adaptive icon foreground: a 108 dp canvas whose middle 72 dp is safe.
for entry in mdpi:108 hdpi:162 xhdpi:216 xxhdpi:324 xxxhdpi:432; do
  density=${entry%%:*}; size=${entry##*:}
  mkdir -p "$RES/mipmap-$density"
  render "$LOGO/nemo-adaptive-foreground.svg" "$size" \
    "$RES/mipmap-$density/ic_launcher_foreground.png"
done

# The status bar draws a notification icon as a silhouette from its alpha
# channel, so this one is the bare white mark on transparency. Pointing it
# at the launcher icon instead would show a filled square.
for entry in mdpi:24 hdpi:36 xhdpi:48 xxhdpi:72 xxxhdpi:96; do
  density=${entry%%:*}; size=${entry##*:}
  mkdir -p "$RES/drawable-$density"
  render "$LOGO/nemo-notification.svg" "$size" \
    "$RES/drawable-$density/ic_notification.png"
done

# Web: favicon plus the manifest icons, maskable ones with more padding.
render "$LOGO/nemo-icon.svg" 32 "$WEB/favicon.png"
mkdir -p "$WEB/icons"
render "$LOGO/nemo-icon.svg" 192 "$WEB/icons/Icon-192.png"
render "$LOGO/nemo-icon.svg" 512 "$WEB/icons/Icon-512.png"
render "$LOGO/nemo-icon-maskable.svg" 192 "$WEB/icons/Icon-maskable-192.png"
render "$LOGO/nemo-icon-maskable.svg" 512 "$WEB/icons/Icon-maskable-512.png"

echo "icons written from $LOGO"
```

In `README.md`, replace the line

```
tool/generate_icons.sh    # needs rsvg-convert (librsvg)
```

with

```
tool/generate_icons.sh    # needs rsvg-convert (librsvg) and magick (ImageMagick)
```

- [ ] **Step 11: Regenerate and check the icons**

```bash
cd /home/ben/repo/nemo_todo-logo
export PATH=$HOME/fvm/versions/3.47.2/bin:$PATH
tool/generate_icons.sh
tool/check_icons.sh
LC_ALL=C grep -ac 'tEXt\|iTXt\|zTXt\|tIME' app/web/icons/Icon-512.png
```

Expected: `icons written from assets/logo`, then `all 20 icons present and none is a stock Flutter image`, then `0`. A stripped PNG has no text or time chunks. Don't use `magick identify -verbose` for this: it always prints `date:` lines taken from the file's timestamps.

- [ ] **Step 12: Look at the result**

```bash
cd /home/ben/repo/nemo_todo-logo
magick app/web/icons/Icon-512.png app/web/icons/Icon-maskable-512.png \
  \( app/android/app/src/main/res/drawable-xxxhdpi/ic_notification.png -background '#303030' -flatten \) \
  +append build/icon-check.png
```

Open `build/icon-check.png`. It must show the white disc with a teal check on the rounded teal tile, the same on the full-bleed tile, and a white disc with a check-shaped hole on dark grey. No fish anywhere.

- [ ] **Step 13: Commit**

```bash
cd /home/ben/repo/nemo_todo-logo
git add assets/logo tool/generate_icons.sh README.md app/web/favicon.png app/web/icons app/android/app/src/main/res/mipmap-mdpi app/android/app/src/main/res/mipmap-hdpi app/android/app/src/main/res/mipmap-xhdpi app/android/app/src/main/res/mipmap-xxhdpi app/android/app/src/main/res/mipmap-xxxhdpi app/android/app/src/main/res/drawable-mdpi app/android/app/src/main/res/drawable-hdpi app/android/app/src/main/res/drawable-xhdpi app/android/app/src/main/res/drawable-xxhdpi app/android/app/src/main/res/drawable-xxxhdpi
git commit -F - <<'EOF'
feat(logo): the mark is a checkmark cut out of a disc

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01KTnpjror3f9jBTwWnhzGse
EOF
```

---

### Task 2: The painted mark, and the docs

**Files:**
- Modify: `app/lib/core/widgets/nemo_mark.dart`
- Test: `app/test/core/widgets/nemo_mark_test.dart`
- Modify: `README.md` (the prose of "The logo")
- Modify: `CHANGELOG.md`

**Interfaces:**
- Consumes: the mark path in `assets/logo/nemo-mark.svg` (Task 1), which the painter mirrors command for command.
- Produces: `NemoMark({double size = 24, Color? color})` and `NemoLogoTile({double size = 40})`, public API unchanged; the tile's mark is `size * 0.76`.

- [ ] **Step 1: Write the failing tests**

In `app/test/core/widgets/nemo_mark_test.dart`, add these imports beside the existing ones:

```dart
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
```

Inside `main()`, after the existing `pump` helper, add:

```dart
  /// The colour of one pixel of [NemoMark] painted on the 512 master canvas,
  /// so the points below are the master artwork's own coordinates.
  Future<Color> pixelOfMark(WidgetTester tester, Offset at) async {
    tester.view.physicalSize = const Size(512, 512);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const boundary = GlobalObjectKey('mark');
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: RepaintBoundary(
            key: boundary,
            child: NemoMark(size: 512, color: Color(0xFF0E7C86)),
          ),
        ),
      ),
    );
    final render = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(boundary),
    );
    final bytes = (await tester.runAsync(() async {
      final image = await render.toImage();
      return image.toByteData(format: ui.ImageByteFormat.rawRgba);
    }))!;
    final i = (at.dy.toInt() * 512 + at.dx.toInt()) * 4;
    return Color.fromARGB(
      bytes.getUint8(i + 3),
      bytes.getUint8(i),
      bytes.getUint8(i + 1),
      bytes.getUint8(i + 2),
    );
  }

  testWidgets('the mark is a disc with the check cut out of it', (
    tester,
  ) async {
    // Inside the disc, below where a clownfish's fins ever reached.
    final disc = await pixelOfMark(tester, const Offset(256, 440));
    expect(disc.a, closeTo(1, 0.01));
    expect(disc.toARGB32(), 0xFF0E7C86);

    // On the check, just above its elbow: a hole, so the background shows.
    final check = await pixelOfMark(tester, const Offset(229, 310));
    expect(check.a, 0);

    // Outside the disc altogether.
    final outside = await pixelOfMark(tester, const Offset(10, 10));
    expect(outside.a, 0);
  });
```

In the existing test `'the tile centres the mark and rounds its corners'`, replace

```dart
    expect(tester.getSize(find.byType(NemoMark)).width, closeTo(52.8, 0.01));
```

with

```dart
    expect(tester.getSize(find.byType(NemoMark)).width, closeTo(60.8, 0.01));
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
cd /home/ben/repo/nemo_todo-logo/app
export PATH=$HOME/fvm/versions/3.47.2/bin:$PATH
flutter test test/core/widgets/nemo_mark_test.dart
```

Expected: FAIL. `the mark is a disc with the check cut out of it` fails on the first `expect`, because the clownfish leaves (256, 440) transparent. `the tile centres the mark and rounds its corners` fails with an actual width of 52.8.

- [ ] **Step 3: Paint the checkmark**

Replace `app/lib/core/widgets/nemo_mark.dart` with:

```dart
import 'package:flutter/material.dart';

/// nemo's mark: a checkmark, cut out of a disc.
///
/// One colour, and the check is a hole rather than a second colour -- so
/// whatever is behind the mark shows through it. That is what lets the
/// same artwork be the teal mark on a page, the white disc on the launcher
/// tile, and the silhouette Android draws in the status bar from nothing
/// but an alpha channel.
///
/// Drawn rather than loaded from an asset so it stays crisp at any size and
/// takes its colour from the theme. The geometry matches
/// `assets/logo/nemo-mark.svg`; change both together.
class NemoMark extends StatelessWidget {
  const NemoMark({this.size = 24, this.color, super.key});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(
      painter: _NemoMarkPainter(color ?? Theme.of(context).colorScheme.primary),
    ),
  );
}

/// The mark inside nemo's rounded tile, as the launcher icon shows it.
class NemoLogoTile extends StatelessWidget {
  const NemoLogoTile({this.size = 40, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF13949F), Color(0xFF0A5C66)],
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Center(
        // The same proportion as assets/logo/nemo-icon.svg.
        child: NemoMark(size: size * 0.76, color: scheme.onPrimary),
      ),
    );
  }
}

class _NemoMarkPainter extends CustomPainter {
  const _NemoMarkPainter(this.color);

  /// The master artwork is drawn on a 512 canvas.
  static const _canvas = 512.0;

  /// Half the width of the check's stroke, which is also the radius of its
  /// rounded ends and its outer corner.
  static const _stroke = Radius.circular(31.5);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / _canvas;
    canvas
      ..save()
      ..scale(scale);
    // The disc, then the outline of the check. The check is a hole, so the
    // whole thing is one path wound even-odd rather than a white check laid
    // over a teal disc.
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..moveTo(56, 256)
      ..arcToPoint(
        const Offset(456, 256),
        radius: const Radius.circular(200),
        largeArc: true,
        clockwise: false,
      )
      ..arcToPoint(
        const Offset(56, 256),
        radius: const Radius.circular(200),
        largeArc: true,
        clockwise: false,
      )
      ..close()
      ..moveTo(127.87, 265.42)
      ..lineTo(206.87, 343.42)
      ..arcToPoint(
        const Offset(251.10, 343.45),
        radius: _stroke,
        clockwise: false,
      )
      ..lineTo(381.10, 215.45)
      ..arcToPoint(
        const Offset(381.45, 170.90),
        radius: _stroke,
        clockwise: false,
      )
      ..arcToPoint(
        const Offset(336.90, 170.55),
        radius: _stroke,
        clockwise: false,
      )
      ..lineTo(229.03, 276.76)
      ..lineTo(172.13, 220.58)
      ..arcToPoint(
        const Offset(127.58, 220.87),
        radius: _stroke,
        clockwise: false,
      )
      ..arcToPoint(
        const Offset(127.87, 265.42),
        radius: _stroke,
        clockwise: false,
      )
      ..close();
    canvas
      ..drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill
          ..isAntiAlias = true,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_NemoMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}
```

SVG `A rx ry 0 large sweep x y` with `sweep = 0` is `clockwise: false` in Flutter's `arcToPoint`, and `large = 1` is `largeArc: true`. The check's arcs are all `0 0`.

- [ ] **Step 4: Run the tests to verify they pass**

```bash
cd /home/ben/repo/nemo_todo-logo/app
export PATH=$HOME/fvm/versions/3.47.2/bin:$PATH
flutter test test/core/widgets/nemo_mark_test.dart
```

Expected: PASS, 4 tests.

- [ ] **Step 5: Render the painted mark next to the SVG and compare**

```bash
cd /home/ben/repo/nemo_todo-logo/app
export PATH=$HOME/fvm/versions/3.47.2/bin:$PATH
flutter test test/design/mark_render_test.dart --update-goldens
cd ..
rsvg-convert -w 200 -h 200 assets/logo/nemo-mark.svg -o build/svg-mark.png
```

Open `app/build/screens/mark.png` and `build/svg-mark.png`. The painted mark on the left of `mark.png` must match the SVG render: same disc, same check, the check a hole. The tile on the right must show a white disc whose check shows the teal gradient through it.

- [ ] **Step 6: Describe the checkmark in the README**

In `README.md`, replace the paragraph that begins `The mark is a **clownfish**` and ends `so the mark is edited in one place:` with:

```markdown
The mark is a **checkmark cut out of a disc**. It is one colour and the
check is a hole rather than a second colour, so whatever is behind the disc
shows through it -- which is what lets one drawing be the teal mark on a
page, the white disc on the launcher tile, and the silhouette Android builds
in the status bar out of nothing but an alpha channel. `assets/logo` holds
the sources; every launcher and web icon is rendered from them, so the mark
is edited in one place:
```

In the next paragraph, replace `down to the
even-odd winding that makes the bands holes;` with `down to the
even-odd winding that makes the check a hole;`. The line break falls after "the", exactly as in the file today.

- [ ] **Step 7: Add the changelog entry**

In `CHANGELOG.md`, insert this directly above `## 0.5.0 - 2026-09-11`:

```markdown
## Unreleased

### Changed

- The mark is a checkmark cut out of a teal disc rather than a clownfish:
  the launcher icon, the splash screen, the favicon, the web app's icon, the
  status bar icon reminders post with, and the mark inside the app.

```

The release commit renames `Unreleased` to `<version> - <date>`, because the release workflow reads the section by its version.

- [ ] **Step 8: Verify the whole change**

```bash
cd /home/ben/repo/nemo_todo-logo
export PATH=$HOME/fvm/versions/3.47.2/bin:$PATH
grep -rn 'M 73 256\|moveTo(73, 256)\|clownfish' assets app/lib README.md
flutter analyze
(cd app && flutter test --exclude-tags design)
dart format --output=none --set-exit-if-changed app/lib app/test
```

Expected: the `grep` prints nothing. The only "clownfish" left is in `CHANGELOG.md`, which it does not search. `flutter analyze` reports `No issues found!`, the app tests all pass, and `dart format` exits 0.

- [ ] **Step 9: Commit**

```bash
cd /home/ben/repo/nemo_todo-logo
git add app/lib/core/widgets/nemo_mark.dart app/test/core/widgets/nemo_mark_test.dart README.md CHANGELOG.md
git commit -F - <<'EOF'
feat(logo): paint the checkmark in the app

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01KTnpjror3f9jBTwWnhzGse
EOF
```
