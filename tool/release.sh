#!/usr/bin/env bash
# Releases a version: the changelog and version bump, a local check, and a
# tag only once CI has passed on the commit it would point at.
#
#   tool/release.sh 0.15.4
#
# A tag is what publishes, and a tag on a commit CI rejects is a release
# that never builds -- 0.15.1 was one, pushed before CI had run. So this
# pushes main first, waits for CI on that exact commit, and tags only if
# it passed. Nothing is tagged otherwise; fix main and run it again with
# the next version.
#
# What it does, in order, stopping at the first problem:
#   1. requires a clean main that is level with origin/main
#   2. renames "## Unreleased" in CHANGELOG.md to "## <version> - <date>"
#      (write the entries there first; a release with none is refused)
#   3. sets app/pubspec.yaml to <version>+<build number + 1>
#   4. commits "chore: release <version>" and runs tool/check.sh on it;
#      if that fails the commit is undone
#   5. pushes main, waits for its CI run, then tags v<version> and pushes
#      the tag, which starts the release workflow
#
# Needs the GitHub CLI (gh), signed in, to watch CI.
set -euo pipefail
cd "$(dirname "$0")/.."

version=${1:-}
if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]]; then
  echo "usage: tool/release.sh <version>, e.g. 0.15.4" >&2
  exit 1
fi
tag="v$version"
fail() {
  echo "release: $*" >&2
  exit 1
}

command -v gh > /dev/null || fail "the GitHub CLI (gh) is needed to watch CI"
[ "$(git branch --show-current)" = main ] || fail "not on main"
[ -z "$(git status --porcelain)" ] || fail "uncommitted changes"
git rev-parse -q --verify "refs/tags/$tag" > /dev/null && fail "$tag exists"
git fetch -q origin main --tags
git rev-parse -q --verify "refs/tags/$tag" > /dev/null && fail "$tag exists"
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] ||
  [ "$(git merge-base HEAD origin/main)" = "$(git rev-parse origin/main)" ] ||
  fail "main has diverged from origin/main; pull first"

grep -q '^## Unreleased$' CHANGELOG.md ||
  fail "CHANGELOG.md has no '## Unreleased' section to release"
# The section runs to the next "## " heading; it has to say something.
entries=$(awk '/^## Unreleased$/ { on = 1; next } on && /^## / { exit }
  on && /^- / { n++ } END { print n + 0 }' CHANGELOG.md)
[ "$entries" -gt 0 ] || fail "'## Unreleased' in CHANGELOG.md has no entries"

current=$(sed -n 's/^version: //p' app/pubspec.yaml)
build=${current#*+}
[[ "$build" =~ ^[0-9]+$ ]] || fail "cannot read the build number of '$current'"
next="$version+$((build + 1))"

today=$(date +%Y-%m-%d)
sed -i "s/^## Unreleased$/## $version - $today/" CHANGELOG.md
sed -i "s/^version: .*/version: $next/" app/pubspec.yaml
git add CHANGELOG.md app/pubspec.yaml
git commit -q -m "chore: release $version"
echo "release: committed $version ($current -> $next)"

if ! tool/check.sh; then
  # Only this script's own commit is undone; nothing had been pushed.
  git reset -q --keep HEAD~1
  fail "tool/check.sh failed; the release commit has been undone"
fi

sha=$(git rev-parse HEAD)
# The check just passed on this tree, so the pre-push hook lets it through.
git push -q origin main
echo "release: pushed main at ${sha:0:7}; waiting for CI to start..."

run=""
for _ in $(seq 60); do
  run=$(gh run list --workflow ci.yml --commit "$sha" --event push \
    --json databaseId -q '.[0].databaseId' 2>/dev/null | tr -cd '0-9' || true)
  [ -n "$run" ] && break
  sleep 10
done
[ -n "$run" ] || fail "no CI run appeared for $sha; tag it by hand once CI passes"

echo "release: watching CI run $run (this takes a while)..."
if ! gh run watch "$run" --exit-status --interval 30 > /dev/null; then
  fail "CI failed on ${sha:0:7}, so $tag was not tagged: gh run view $run"
fi

git tag "$tag" "$sha"
git push -q origin "$tag"
echo "release: CI passed; pushed $tag, which starts the release workflow"
echo "  gh run list --workflow release.yml --limit 1"
