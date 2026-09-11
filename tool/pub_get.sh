#!/usr/bin/env bash
# Resolves dependencies, and asks again when the failure was pub.dev's
# rather than ours.
#
# The 0.3.0 release died on `cupertino_ui ... doesn't exist (authorization
# failed)`, with pub.dev answering 403 for a package that is published and
# pinned by sha256 in pubspec.lock. Nothing in this repository can fix
# that, the versions were never in doubt, and the next attempt a minute
# later succeeded -- so a build now waits and asks again instead of
# failing a release on someone else's bad minute.
#
# Runs `flutter pub get` unless given another command, so the server image
# can pass `dart pub get` for the stage that has no Flutter.
set -euo pipefail

attempts="${PUB_GET_ATTEMPTS:-4}"
delay="${PUB_GET_DELAY:-15}"

if [ "$#" -eq 0 ]; then
  set -- flutter pub get
fi

attempt=1
while true; do
  if "$@"; then
    exit 0
  fi
  if [ "$attempt" -ge "$attempts" ]; then
    echo "tool/pub_get.sh: '$*' failed $attempts times; giving up" >&2
    exit 1
  fi
  echo "tool/pub_get.sh: '$*' failed (attempt $attempt of $attempts);" \
       "trying again in ${delay}s" >&2
  sleep "$delay"
  attempt=$((attempt + 1))
  delay=$((delay * 2))
done
