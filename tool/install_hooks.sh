#!/usr/bin/env bash
# Points this clone's hooks at the ones in .githooks, which are tracked.
#
# Git does not version .git/hooks, so a hook is only useful if every clone
# is told where to find it. One line, and it survives a pull.
set -euo pipefail
cd "$(dirname "$0")/.."

git config core.hooksPath .githooks
echo "hooks installed: $(git config core.hooksPath)"
echo "skip one with 'git commit --no-verify'; undo with"
echo "  git config --unset core.hooksPath"
