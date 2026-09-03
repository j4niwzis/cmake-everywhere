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

# What a project built, if it built something to run. A test that only
# builds says the symbols were found; a test that runs says which library
# they were found in.
run_if_built() {
  for binary in "$1"/cme-*; do
    if [ -x "$binary" ] && [ -f "$binary" ]; then
      "$binary" || return 1
    fi
  done
  return 0
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
       -DCME_LOCK= \
       "$@" >"$out/$name.log" 2>&1 &&
     cmake --build "$directory" >>"$out/$name.log" 2>&1 &&
     run_if_built "$directory" >>"$out/$name.log" 2>&1; then
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
       -DCME_LOCK= \
       -DCME_REGISTRY="$here/registry" >"$out/$name.log" 2>&1; then
    report 1 "$name  (configured, and should not have)"
  elif grep -qF "$because" "$out/$name.log"; then
    report 0 "$name"
  else
    report 1 "$name  (refused for the wrong reason, see $out/$name.log)"
  fi
}

mkdir -p "$out"

# Before anything is fetched or configured: a command that is called and
# never defined is a mistake that would otherwise be found after a download
# and a gn run.
if python3 "$root/check.py" >"$out/check.log" 2>&1; then
  report 0 "commands"
else
  report 1 "commands"
  cat "$out/check.log"
fi

echo "refusals -- nothing is fetched, these are decided before that"
expect_refusal unknown-feature       "has none by that name"
expect_refusal conflicting-features  "can have at most one of"
expect_refusal implied-by-variable   "can have at most one of"
expect_refusal implied-through-a-chain "this build refuses chain-c"
expect_refusal refused-feature       "this build refuses"
expect_refusal licence               "accepts only"
expect_refusal missing-port          "there is no port called"

echo "the store -- built once, found again, and not found when it should not be"
if "$here/store.sh" "$out/store" >"$out/store.log" 2>&1; then
  sed 's/^/  /' "$out/store.log"
  passed=$((passed + 1))
else
  sed 's/^/  /' "$out/store.log"
  report 1 "store  (see $out/store.log)"
fi

echo "ports from anywhere -- a library nobody has ported, used three ways"
if "$here/decentral.sh" "$out/decentral" >"$out/decentral.log" 2>&1; then
  sed 's/^/  /' "$out/decentral.log"
  passed=$((passed + 1))
else
  sed 's/^/  /' "$out/decentral.log"
  report 1 "decentral  (see $out/decentral.log)"
fi

echo "pkg-config -- a project that asks the other way round"
expect_build pkgconfig "$here/pkgconfig" -DCME_SYSTEM=NEVER

echo "builds"
expect_build features "$here/features"
expect_build features-from-source "$here/features" -DCME_SYSTEM=NEVER
expect_build consumer "$here"
expect_build consumer-from-source "$here" -DCME_SYSTEM=NEVER

# Skia twice, and the second one is the one that means something. With the
# system's libraries available, Skia is handed those and nothing this
# registry built is ever reached; from source, zlib, libpng and freetype are
# built here and Skia has to be made to use them rather than whatever the
# linker finds.
if [ "$1" = "--with-skia" ] || [ "$1" = "--with-skia-features" ]; then
  echo "skia -- needs gn, and takes a while"
  expect_build skia "$here/skia"
fi
if [ "$1" = "--with-skia-features" ]; then
  echo "skia with features, from source -- takes longer still"
  expect_build skia-features "$here/skia" \
    -DCME_SYSTEM=NEVER -DCME_FEATURES_skia="gl;png;freetype"
fi

echo
printf '%d passed, %d failed\n' "$passed" "$failed"
[ "$failed" = 0 ]
