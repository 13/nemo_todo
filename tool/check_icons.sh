#!/usr/bin/env bash
# Fails when an icon is missing or is still one of Flutter's stock images.
#
# Comparing freshly rendered PNGs against the committed ones would be the
# stricter check, but rsvg renders differently from version to version, so
# it would fail on machines that are perfectly fine. This catches what
# actually went wrong: a template icon nobody replaced.
set -euo pipefail
cd "$(dirname "$0")/.."

RES=app/android/app/src/main/res
WEB=app/web

expected=(
  "$WEB/favicon.png"
  "$WEB/icons/Icon-192.png"
  "$WEB/icons/Icon-512.png"
  "$WEB/icons/Icon-maskable-192.png"
  "$WEB/icons/Icon-maskable-512.png"
)
for density in mdpi hdpi xhdpi xxhdpi xxxhdpi; do
  expected+=("$RES/mipmap-$density/ic_launcher.png")
  expected+=("$RES/mipmap-$density/ic_launcher_foreground.png")
  expected+=("$RES/drawable-$density/ic_notification.png")
done

missing=0
for file in "${expected[@]}"; do
  if [ ! -f "$file" ]; then
    echo "missing icon: $file" >&2
    missing=1
  fi
done
[ "$missing" -eq 0 ] || exit 1

flutter_root=${FLUTTER_ROOT:-}
if [ -z "$flutter_root" ] && command -v flutter > /dev/null; then
  flutter_root=$(dirname "$(dirname "$(readlink -f "$(command -v flutter)")")")
fi
[ -n "$flutter_root" ] || flutter_root="$HOME/flutter"
templates="$flutter_root/packages/flutter_tools/templates"
if [ ! -d "$templates" ]; then
  echo "Flutter templates not found at $templates; skipping the stock check" >&2
  echo "all expected icons are present"
  exit 0
fi

stock=$(find "$templates" -name '*.png*' -exec md5sum {} + | cut -d' ' -f1 | sort -u)
failed=0
for file in "${expected[@]}"; do
  if grep -qx "$(md5sum "$file" | cut -d' ' -f1)" <<< "$stock"; then
    echo "still Flutter's stock image: $file" >&2
    failed=1
  fi
done
[ "$failed" -eq 0 ] || {
  echo "run tool/generate_icons.sh and commit the result" >&2
  exit 1
}
echo "all ${#expected[@]} icons present and none is a stock Flutter image"
