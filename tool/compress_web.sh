#!/usr/bin/env bash
# Writes a brotli and a gzipped copy next to each large file of a built
# web app, which the server sends in place of the original to a browser
# that accepts that encoding. Compressing once here costs nothing per
# request; compressing on every request would cost the server more than
# the file does, and brotli at its best setting far more.
#
# A copy that comes out no smaller than its original is dropped, so the
# server never sends a file bigger than it has to.
set -euo pipefail
dir="${1:-$(cd "$(dirname "$0")/.." && pwd)/app/build/web}"
if [ ! -d "$dir" ]; then
  echo "no web build at $dir" >&2
  exit 1
fi
for tool in gzip brotli; do
  if ! command -v "$tool" > /dev/null; then
    echo "$tool is not installed" >&2
    exit 1
  fi
done

# Keeps a compressed copy only if it is smaller, dated like its original:
# the server answers If-Modified-Since from the copy it sends. Prints the
# size the file will go out at either way.
keep() {
  local size zipped
  size=$(wc -c < "$1")
  zipped=$(wc -c < "$2")
  if [ "$zipped" -ge "$size" ]; then
    rm "$2"
    echo "$size"
  else
    touch -r "$1" "$2"
    echo "$zipped"
  fi
}

count=0
before=0
gz_total=0
br_total=0
while IFS= read -r -d '' file; do
  gzip -9 --keep --force --no-name "$file"
  brotli --best --keep --force "$file"
  gz=$(keep "$file" "$file.gz")
  br=$(keep "$file" "$file.br")
  count=$((count + 1))
  before=$((before + $(wc -c < "$file")))
  gz_total=$((gz_total + gz))
  br_total=$((br_total + br))
# Not *.symbols: those are only fetched to symbolise a stack trace, and
# brotli takes longer over them than over everything else together.
done < <(find "$dir" -type f -size +1k \
  \( -name '*.js' -o -name '*.mjs' -o -name '*.wasm' -o -name '*.json' \
     -o -name '*.ttf' -o -name '*.otf' -o -name 'NOTICES' \) -print0)
echo "compressed $count files: $before bytes, $gz_total gzipped," \
     "$br_total as brotli"
