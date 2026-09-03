#!/bin/sh
# Whether the store is a store.
#
# Three questions, and none of them is "did it go faster", because a timing
# is not an answer. The build writes down where every library came from, so
# the questions are asked of that: built, then found, and then not found when
# it should not be.
set -e
here=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$here")
provider="$root/cmake-everywhere.cmake"
work="${1:-$root/build/store-check}"
store="$work/store"
rm -rf "$work"
mkdir -p "$store"
failed=0

port=zlib
package=ZLIB
targets=ZLIB::ZLIB

# Where the build says a library came from. "built" the first time, "store"
# once there is something to find.
came_from() {
  awk -v port="$1" '$1 == port { how = $2 } END { print how }' "$2/cme-report.txt"
}

configure() {
  directory=$1
  shift
  cmake -S "$here/port" -B "$directory" -G Ninja \
    -DCMAKE_PROJECT_TOP_LEVEL_INCLUDES="$provider" \
    -DCME_LOCK= \
    -DCME_STORE="$store" \
    -DCME_SYSTEM=NEVER \
    -DCME_PORT_PACKAGE="$package" \
    -DCME_PORT_TARGETS="$targets" \
    "$@" >"$directory.log" 2>&1
}

check() {
  if [ "$2" = "$3" ]; then
    printf '  ok    %s\n' "$1"
  else
    printf '  FAIL  %s: expected %s, got %s\n' "$1" "$3" "$2"
    failed=$((failed + 1))
  fi
}

# One: a library nobody has built before is built, and is in the store
# afterwards.
configure "$work/first"
cmake --build "$work/first" >>"$work/first.log" 2>&1
"$work/first/cme-port" >/dev/null
check "first build builds it" "$(came_from $port "$work/first")" "built"
if [ -n "$(find "$store" -name complete -print -quit 2>/dev/null)" ]; then
  printf '  ok    it is in the store\n'
else
  printf '  FAIL  nothing in the store\n'
  failed=$((failed + 1))
fi

# Two: another build directory entirely, everything else the same. Nothing
# is fetched and nothing is compiled; the library comes out of the store and
# still links and runs.
configure "$work/second"
cmake --build "$work/second" >>"$work/second.log" 2>&1
"$work/second/cme-port" >/dev/null
check "a second build finds it" "$(came_from $port "$work/second")" "store"

# Three: the same library with a flag it was not built with. Under EXACT the
# flags are part of the name, so this is a different name and a real build.
# The mode is part of the name too, so this one is built rather than found
# whatever else is true -- which is why the fourth question is asked twice in
# the same mode rather than compared against the two above.
configure "$work/third" -DCME_STORE_MATCH=EXACT -DCMAKE_C_FLAGS="-DCME_CHECK=1"
cmake --build "$work/third" >>"$work/third.log" 2>&1
check "a flag that counts is a different library" \
  "$(came_from $port "$work/third")" "built"

configure "$work/third-again" -DCME_STORE_MATCH=EXACT \
  -DCMAKE_C_FLAGS="-DCME_CHECK=1"
cmake --build "$work/third-again" >>"$work/third-again.log" 2>&1
check "and is found once it has been built" \
  "$(came_from $port "$work/third-again")" "store"

# Four: the same difference, in a mode that does not count it. The first of
# these builds -- nothing has been kept under this mode -- and the second
# finds it despite the flags having changed again.
configure "$work/fourth" -DCME_STORE_MATCH=LOOSE -DCMAKE_C_FLAGS="-DCME_CHECK=2"
cmake --build "$work/fourth" >>"$work/fourth.log" 2>&1
configure "$work/fifth" -DCME_STORE_MATCH=LOOSE -DCMAKE_C_FLAGS="-DCME_CHECK=3"
cmake --build "$work/fifth" >>"$work/fifth.log" 2>&1
check "a flag that does not count is the same library" \
  "$(came_from $port "$work/fifth")" "store"

# When something is wrong, what the build said about keeping libraries is
# the first thing worth reading, and it is buried in a log nobody opened.
if [ "$failed" != 0 ]; then
  echo
  echo "what the builds said about the store:"
  grep -h "is not kept\|will be kept\|is already built\|reusing it\|kept /\|cannot put" \
    "$work"/*.log 2>/dev/null | sed 's/^/    /' || echo "    (nothing)"
  echo "what is in $store:"
  find "$store" -maxdepth 3 2>/dev/null | sed 's/^/    /' || true
  exit 1
fi
