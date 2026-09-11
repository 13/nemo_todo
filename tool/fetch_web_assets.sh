#!/usr/bin/env bash
# Downloads the sqlite3 WebAssembly build and the drift web worker that the
# app needs to run its database in the browser. Versions must match the
# `sqlite3` and `drift` packages in pubspec.lock. Output is gitignored.
set -euo pipefail
cd "$(dirname "$0")/../app/web"

SQLITE3_VERSION="${SQLITE3_VERSION:-3.5.2}"
DRIFT_VERSION="${DRIFT_VERSION:-2.34.4}"

# --retry for the same reason tool/pub_get.sh retries: a release should not
# die because GitHub's downloads had a bad minute.
curl -fsSL --retry 4 --retry-delay 5 --retry-all-errors -o sqlite3.wasm \
  "https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-${SQLITE3_VERSION}/sqlite3.wasm"
curl -fsSL --retry 4 --retry-delay 5 --retry-all-errors -o drift_worker.js \
  "https://github.com/simolus3/drift/releases/download/drift-${DRIFT_VERSION}/drift_worker.js"
echo "fetched sqlite3.wasm ($(wc -c < sqlite3.wasm) bytes) and drift_worker.js ($(wc -c < drift_worker.js) bytes)"
