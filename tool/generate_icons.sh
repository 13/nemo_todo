#!/usr/bin/env bash
# Renders every launcher and web icon from the SVG masters in assets/logo.
# Needs rsvg-convert (librsvg). Run from anywhere:
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

render() { rsvg-convert -w "$2" -h "$2" "$1" -o "$3"; }

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

# Web: favicon plus the manifest icons, maskable ones with more padding.
render "$LOGO/nemo-icon.svg" 32 "$WEB/favicon.png"
mkdir -p "$WEB/icons"
render "$LOGO/nemo-icon.svg" 192 "$WEB/icons/Icon-192.png"
render "$LOGO/nemo-icon.svg" 512 "$WEB/icons/Icon-512.png"
render "$LOGO/nemo-icon-maskable.svg" 192 "$WEB/icons/Icon-maskable-192.png"
render "$LOGO/nemo-icon-maskable.svg" 512 "$WEB/icons/Icon-maskable-512.png"

echo "icons written from $LOGO"
