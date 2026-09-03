#!/bin/sh
# Every check, in the order of how long it takes and how much it needs.
#
#   test/run.sh              the ones that need nothing but a compiler
#   test/run.sh --with-skia  and the one that needs gn and a long wait
set -e
here=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$here")
out="$root/build/check"
provider="$root/cmake-everywhere.cmake"
passed=0
failed=0

report() {
  if [ "$1" = 0 ]; then
    passed=$((passed + 1))
    printf '  ok    %s\n' "$2"
  else
    failed=$((failed + 1))
    printf '  FAIL  %s\n' "$2"
  fi
}

# A project that has to configure, build and link.
expect_build() {
  name=$1
  source=$2
  shift 2
  directory="$out/$name"
  rm -rf "$directory"
  if cmake -S "$source" -B "$directory" -G Ninja \
       -DCMAKE_PROJECT_TOP_LEVEL_INCLUDES="$provider" \
       "$@" >"$out/$name.log" 2>&1 &&
     cmake --build "$directory" >>"$out/$name.log" 2>&1; then
    report 0 "$name"
  else
    report 1 "$name  (see $out/$name.log)"
  fi
}

# A project that has to be refused, for the stated reason. A wrong reason is
# as much a failure as no reason: the message is the feature.
expect_refusal() {
  name=$1
  because=$2
  directory="$out/$name"
  rm -rf "$directory"
  if cmake -S "$here/cases/$name" -B "$directory" \
       -DCMAKE_PROJECT_TOP_LEVEL_INCLUDES="$provider" \
       -DCME_REGISTRY="$here/registry" >"$out/$name.log" 2>&1; then
    report 1 "$name  (configured, and should not have)"
  elif grep -qF "$because" "$out/$name.log"; then
    report 0 "$name"
  else
    report 1 "$name  (refused for the wrong reason, see $out/$name.log)"
  fi
}

mkdir -p "$out"
echo "refusals -- nothing is fetched, these are decided before that"
expect_refusal unknown-feature       "has none by that name"
expect_refusal conflicting-features  "can have at most one of"
expect_refusal refused-feature       "this build refuses"
expect_refusal licence               "accepts only"
expect_refusal missing-port          "there is no port called"

echo "builds"
expect_build features "$here/features"
expect_build features-from-source "$here/features" -DCME_SYSTEM=NEVER
expect_build consumer "$here"
expect_build consumer-from-source "$here" -DCME_SYSTEM=NEVER

if [ "$1" = "--with-skia" ]; then
  echo "skia -- needs gn, and takes a while"
  expect_build skia "$here/skia"
fi

echo
printf '%d passed, %d failed\n' "$passed" "$failed"
[ "$failed" = 0 ]
