#!/usr/bin/env bash
# Writes a gzipped copy next to each large file of a built web app, which
# the server sends in place of the original to a browser that accepts
# gzip. Compressing once here costs nothing per request; compressing on
# every request would cost the server more than the file does.
#
# A copy that comes out no smaller than its original is dropped, so the
# server never sends a file bigger than it has to.
set -euo pipefail
dir="${1:-$(cd "$(dirname "$0")/.." && pwd)/app/build/web}"
if [ ! -d "$dir" ]; then
  echo "no web build at $dir" >&2
  exit 1
fi

count=0
before=0
after=0
while IFS= read -r -d '' file; do
  gzip -9 --keep --force --no-name "$file"
  size=$(wc -c < "$file")
  zipped=$(wc -c < "$file.gz")
  if [ "$zipped" -ge "$size" ]; then
    rm "$file.gz"
    continue
  fi
  # The server answers If-Modified-Since from the copy it sends, so the
  # copy keeps its original's date.
  touch -r "$file" "$file.gz"
  count=$((count + 1))
  before=$((before + size))
  after=$((after + zipped))
done < <(find "$dir" -type f -size +1k \
  \( -name '*.js' -o -name '*.mjs' -o -name '*.wasm' -o -name '*.json' \
     -o -name '*.ttf' -o -name '*.otf' -o -name '*.symbols' \
     -o -name 'NOTICES' \) -print0)
echo "compressed $count files: $before -> $after bytes"
