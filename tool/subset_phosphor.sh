#!/usr/bin/env bash
# Subsets Phosphor's fonts to the glyphs app/lib/core/widgets/app_icon.dart
# names, into app/assets/fonts. Run it after mapping another icon there;
# app/test/core/widgets/app_icon_font_test.dart fails until you do.
#
# The full fonts come from the phosphor_flutter package in the pub cache
# (`dart pub cache add phosphor_flutter` fetches it; nemo cannot depend on
# it, see app/pubspec.yaml), or from $PHOSPHOR_FONTS. Needs pyftsubset
# (fonttools), else runs it through uvx.
#   tool/subset_phosphor.sh
set -euo pipefail
cd "$(dirname "$0")/.."

src=${PHOSPHOR_FONTS:-}
if [ -z "$src" ]; then
  src=$(find "${PUB_CACHE:-$HOME/.pub-cache}/hosted/pub.dev" -maxdepth 1 \
    -name 'phosphor_flutter-*' 2> /dev/null | sort -V | tail -n 1)
  [ -n "$src" ] && src=$src/lib/fonts
fi
[ -f "$src/Phosphor.ttf" ] || {
  echo "Phosphor's fonts not found; run 'dart pub cache add phosphor_flutter'" \
    "or set PHOSPHOR_FONTS to a folder holding Phosphor.ttf" >&2
  exit 1
}

if command -v pyftsubset > /dev/null; then
  subset=(pyftsubset)
elif command -v uvx > /dev/null; then
  subset=(uvx --from fonttools pyftsubset)
else
  echo "pyftsubset not found; install fonttools (or uv)" >&2
  exit 1
fi

# The code points one family draws, as U+XXXX,U+YYYY.
codepoints() {
  tr -d ' \n' < app/lib/core/widgets/app_icon.dart |
    grep -oE "IconData\(0x[0-9a-f]+,fontFamily:'$1'" |
    grep -oE '0x[0-9a-f]+' | sort -u | sed 's/^0x/U+/' | paste -sd, -
}

for pair in Phosphor.ttf:PhosphorRegular Phosphor-Fill.ttf:PhosphorFill; do
  font=${pair%%:*}
  family=${pair##*:}
  "${subset[@]}" "$src/$font" --unicodes="$(codepoints "$family")" \
    --output-file="app/assets/fonts/$family.ttf"
  echo "$family: $(codepoints "$family" | tr ',' '\n' | wc -l) glyphs"
done
