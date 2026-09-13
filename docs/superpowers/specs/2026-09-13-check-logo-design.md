# A checkmark for the logo

## Goal

nemo's mark becomes a checkmark: a disc with a rounded check cut out of
it, drawn after the picture the owner supplied (`logo.png`, a navy disc with
a white check). It replaces the clownfish everywhere the mark appears — the
launcher icon, the adaptive icon and splash, the status bar, the favicon and
web manifest icons, the wordmark, and the mark painted inside the app.

## Decisions

| Topic | Decision |
|---|---|
| Colour | The brand stays teal: `#0E7C86`, the tile gradient `#13949F` → `#0A5C66`, and the app theme are unchanged. The picture's navy is not adopted |
| Shape | A disc with the check as a hole, one path wound even-odd |
| Tiles | Launcher and web tiles stay the rounded square they are today |
| Source | Hand-built vector geometry taken from the picture's proportions, not a trace of the PNG |
| `logo.png` | Reference only; it is not committed, moved or deleted |

## Why this shape

The clownfish works because it is one colour and its bands are holes, so the
background shows through: the teal mark on a page, the white mark on the
teal tile, and the silhouette Android draws in the status bar from nothing
but an alpha channel. A disc with the check cut out keeps that property, so
every asset keeps its current recipe and only the geometry changes.

Tracing the picture with potrace would copy its compression artefacts into
lumpy curves, and the in-app painter could not mirror a traced path command
for command. Shipping the PNG would blur at launcher sizes and could not take
its colour from the theme. Geometry built from a handful of numbers avoids
both, and is what "optimised" means for a mark: a path of two arcs, four
lines and five small arcs instead of a 306 KB raster.

## Geometry

All masters use a 512 × 512 canvas.

**Disc:** centre (256, 256), radius 200.

```
M 56 256 A 200 200 0 1 0 456 256 A 200 200 0 1 0 56 256 Z
```

**Check:** the outline of a stroke through the centreline
A (150, 243) → B (229, 321) → C (359, 193), half-width 31.5, with round caps
and a round outer join. The inner corner at B stays sharp, as in the picture.
These centreline points are the picture's check re-measured onto a radius-200
disc; its bounding box is centred on the disc.

```
M 127.87 265.42 L 206.87 343.42 A 31.5 31.5 0 0 0 251.10 343.45 L 381.10 215.45 A 31.5 31.5 0 0 0 381.45 170.90 A 31.5 31.5 0 0 0 336.90 170.55 L 229.03 276.76 L 172.13 220.58 A 31.5 31.5 0 0 0 127.58 220.87 A 31.5 31.5 0 0 0 127.87 265.42 Z
```

**The mark** is the disc followed by the check in one `path`,
`fill-rule="evenodd"`.

## Assets

Each master in `assets/logo` keeps its file name and its role, and has its
fish path replaced by the mark. Transforms scale the mark about the canvas
centre: `translate(256·(1−s) 256·(1−s)) scale(s)`.

| File | Mark colour | Placement |
|---|---|---|
| `nemo-mark.svg` | `#0E7C86` | Full size, no transform |
| `nemo-mark-white.svg` | `#FFFFFF` | Full size, no transform |
| `nemo-icon.svg` | `#FFFFFF` | On the existing gradient tile (`rx="116"`), `s = 0.76` |
| `nemo-icon-maskable.svg` | `#FFFFFF` | On the existing full-bleed gradient, `s = 0.66` |
| `nemo-adaptive-foreground.svg` | `#FFFFFF` | Transparent canvas, `s = 0.6`, inside the 72/108 safe zone |
| `nemo-adaptive-background.svg` | — | Unchanged |
| `nemo-notification.svg` | `#FFFFFF` | Transparent canvas, `translate(-25.6 -25.6) scale(1.1)` |
| `nemo-wordmark.svg`, `nemo-wordmark-dark.svg` | Each file's existing mark colour | `translate(49 61) scale(0.375)`: the disc is about 1.6× the lettering's x-height, centred on it, with a clear gap before the "n". The lettering is unchanged |

The scales were checked by rendering: at 48 px the check on the tile is
legible, and at 24 px the status bar silhouette still reads as a check.

## Rendered icons

`tool/generate_icons.sh` renders every Android and web PNG from the masters,
as it does today; the list of outputs and their sizes do not change. It gains
one step after rendering: each PNG it wrote is re-saved with metadata stripped
and maximum lossless compression
(`magick <file> -strip -define png:compression-level=9 <file>`). ImageMagick
becomes a stated requirement of the script beside `rsvg-convert`, checked
the same way. The Android splash (`launch_background.xml`, `values-v31`
styles) already points at `ic_launcher_foreground`, so it needs no change.

## The app

`app/lib/core/widgets/nemo_mark.dart`:

- `_NemoMarkPainter` draws the disc and the check as one even-odd `Path`
  mirroring the geometry above command for command: `arcToPoint` for the
  disc's two arcs and the check's five small arcs (radius 31.5), `lineTo` for
  its straight edges.
- `NemoMark` keeps its API: `size`, `color` defaulting to the theme's
  `primary`.
- `NemoLogoTile` keeps its gradient and corner radius; the mark inside it is
  sized `size * 0.76`, matching `nemo-icon.svg`.
- The doc comments describe the checkmark instead of the clownfish, and still
  say the geometry mirrors `assets/logo/nemo-mark.svg`.

## Documentation

- `README.md`, "The logo": describes the checkmark and why it is a disc with
  a hole, keeping the generate/check commands and the note about the painter
  mirroring the SVG. The `generate_icons.sh` comment there names ImageMagick
  beside `rsvg-convert`. CI renders nothing, so it needs neither.
- `CHANGELOG.md`: a `### Changed` entry for the next release, in the file's
  voice: the mark is a checkmark in a disc rather than a clownfish, wherever
  the old mark appeared.

## Verification

- `tool/generate_icons.sh` runs clean, and `tool/check_icons.sh` passes.
- `flutter test test/design --update-goldens` renders `build/screens/mark.png`;
  the painted mark and tile match the SVG renders by eye.
- `flutter analyze` from the repo root and the app's test suite pass.
- None of the old fish path (`M 73 256 C 79 196`) remains in `assets/` or
  `app/lib`.

## Out of scope

The theme colours, the app's name, the wordmark's lettering, iOS assets
(the project has none), and anything to do with `logo.png` itself.
