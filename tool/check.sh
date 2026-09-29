#!/usr/bin/env bash
# Runs what CI's "Analyze & test" job runs, in the same order, on this
# working tree, and stops at the first failure.
#
# CI finding a problem costs a wasted release: 0.15.1 was tagged after a
# local `flutter analyze` said "No issues", because locally that command
# does not load the riverpod_lint plugin CI enforces, and the release never
# built. `dart analyze` from the workspace root does load it, so that is
# what runs here.
#
#   tool/check.sh          everything CI checks
#   tool/check.sh --quick  skip regenerating code (the pre-commit hook
#                          already checks it for every commit)
#
# Flutter is found on PATH, else under $FLUTTER_ROOT, else ~/flutter.
set -euo pipefail
cd "$(dirname "$0")/.."
root=$PWD

quick=false
[ "${1:-}" = "--quick" ] && quick=true

if ! command -v flutter > /dev/null; then
  for dir in "${FLUTTER_ROOT:-}" "$HOME/flutter"; do
    if [ -n "$dir" ] && [ -x "$dir/bin/flutter" ]; then
      PATH="$dir/bin:$PATH"
      break
    fi
  done
fi
if ! command -v flutter > /dev/null; then
  echo "check: flutter not found on PATH, in \$FLUTTER_ROOT or ~/flutter" >&2
  exit 1
fi

# Git hooks run with GIT_DIR and friends set, which the Flutter SDK's own
# git calls would then read instead of the SDK's repository.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR

started=$SECONDS
step() {
  echo ""
  echo "== $1"
}

# What the generators write. Only a change they make here counts: a file
# already modified beforehand is the author's work in progress.
generated='\.(g|freezed)\.dart$|app/lib/l10n/app_localizations|drift_schemas/.*\.json$|server/test/generated/'
snapshot() {
  { git diff --name-only; git ls-files --others --exclude-standard; } \
    | grep -E "$generated" | sort | while read -r f; do
      echo "$f $(git hash-object "$f" 2>/dev/null || echo gone)"
    done
}

if ! $quick; then
  step "generated code is current"
  before=$(snapshot || true)
  (cd app && flutter gen-l10n > /dev/null)
  (cd packages/nemo_core && dart run build_runner build > /dev/null)
  (cd server && dart run build_runner build > /dev/null)
  (cd app && dart run build_runner build > /dev/null)
  (cd server && dart run drift_dev schema dump \
    lib/src/db/server_database.dart drift_schemas/ > /dev/null)
  (cd server && dart run drift_dev schema generate \
    drift_schemas/ test/generated/ > /dev/null)
  (cd app && dart run drift_dev schema dump \
    lib/core/db/app_database.dart drift_schemas/ > /dev/null)
  after=$(snapshot || true)
  stale=$(comm -13 <(printf '%s\n' "$before") <(printf '%s\n' "$after") \
    | sed 's/ [^ ]*$//' | grep -v '^$' || true)
  if [ -n "$stale" ]; then
    echo "generated files were out of date and have been regenerated:" >&2
    sed 's/^/  /' <<< "$stale" >&2
    exit 1
  fi
fi

step "formatting"
dart format --output=none --set-exit-if-changed \
  packages/nemo_core/lib packages/nemo_core/test \
  server/lib server/bin server/test \
  app/lib app/test tool

step "icons"
tool/check_icons.sh

step "analyze"
dart analyze --fatal-infos

# Each package's tests with the coverage floor CI holds it to.
covered() {
  local dir=$1 floor=$2
  step "test $dir (coverage floor $floor%)"
  (
    cd "$dir"
    rm -rf coverage
    dart test --coverage=coverage --reporter=failures-only
    dart run coverage:format_coverage --lcov --in=coverage \
      --out=coverage/lcov.info --report-on=lib --base-directory=. > /dev/null
    dart run "$root/tool/check_coverage.dart" "$floor" | sed -n 1p
  )
}
covered packages/nemo_core 90
covered server 85

step "test app (coverage floor 80%)"
(
  cd app
  # The design tests compare screenshots, which depend on the machine's
  # font rendering; CI leaves them out, and so does this.
  flutter test --coverage --exclude-tags design --reporter=failures-only
  dart run ../tool/check_coverage.dart 80 | sed -n 1p
)

step "test app dates in a daylight saving time zone"
(cd app && TZ=Europe/Berlin flutter test --tags dst --reporter=failures-only)

# Remember a clean tree that passed in full, so pushing it again -- main
# and then its tag -- does not check it twice (see .githooks/pre-push).
if ! $quick && [ -z "$(git status --porcelain)" ]; then
  git rev-parse 'HEAD^{tree}' >> "$(git rev-parse --git-common-dir)/nemo-checked"
fi

echo ""
echo "check: all passed in $((SECONDS - started))s"
