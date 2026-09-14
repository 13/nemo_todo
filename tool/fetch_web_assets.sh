#!/usr/bin/env bash
# Downloads the sqlite3 WebAssembly build and the drift web worker that the
# app needs to run its database in the browser. Output is gitignored.
#
# The versions have to match the `sqlite3` and `drift` packages the app is
# built with, so they are read from pubspec.lock rather than written here: a
# number written here went on fetching the old worker after a dependency
# update, and nothing would have said so until a browser failed to open
# its database. Set SQLITE3_VERSION or DRIFT_VERSION to override.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"

locked() {
  awk -v pkg="$1" '
    $0 ~ "^  " pkg ":$" { inside = 1; next }
    inside && /^  [^ ]/ { exit }
    inside && $1 == "version:" { gsub(/"/, "", $2); print $2; exit }
  ' "$root/pubspec.lock"
}

SQLITE3_VERSION="${SQLITE3_VERSION:-$(locked sqlite3)}"
DRIFT_VERSION="${DRIFT_VERSION:-$(locked drift)}"
if [ -z "$SQLITE3_VERSION" ] || [ -z "$DRIFT_VERSION" ]; then
  echo "could not read sqlite3 and drift versions from pubspec.lock" >&2
  exit 1
fi
echo "sqlite3 $SQLITE3_VERSION, drift $DRIFT_VERSION"
cd "$root/app/web"

# --retry for the same reason tool/pub_get.sh retries: a release should not
# die because GitHub's downloads had a bad minute.
curl -fsSL --retry 4 --retry-delay 5 --retry-all-errors -o sqlite3.wasm \
  "https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-${SQLITE3_VERSION}/sqlite3.wasm"
curl -fsSL --retry 4 --retry-delay 5 --retry-all-errors -o drift_worker.js \
  "https://github.com/simolus3/drift/releases/download/drift-${DRIFT_VERSION}/drift_worker.js"
echo "fetched sqlite3.wasm ($(wc -c < sqlite3.wasm) bytes) and drift_worker.js ($(wc -c < drift_worker.js) bytes)"
