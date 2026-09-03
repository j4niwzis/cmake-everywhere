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
  awk -v port="$1" '$1 == port { how = $2 } END { print how }' "$2/cme-lock.txt"
}

configure() {
  directory=$1
  shift
  cmake -S "$here/port" -B "$directory" -G Ninja \
    -DCMAKE_PROJECT_TOP_LEVEL_INCLUDES="$provider" \
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
if [ -f "$store/$port"/*/complete ]; then
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

# Three: the same library, asked for differently. EXACT means the flags are
# part of the name, so this is a different name and has to be built.
configure "$work/third" -DCME_STORE_MATCH=EXACT -DCMAKE_C_FLAGS="-DCME_CHECK=1"
cmake --build "$work/third" >>"$work/third.log" 2>&1
check "a different build is not it" "$(came_from $port "$work/third")" "built"

# Four: and with the difference allowed, it is found again.
configure "$work/fourth" -DCME_STORE_MATCH=LOOSE -DCMAKE_C_FLAGS="-DCME_CHECK=2"
cmake --build "$work/fourth" >>"$work/fourth.log" 2>&1
check "a difference that is allowed still finds it" \
  "$(came_from $port "$work/fourth")" "store"

[ "$failed" = 0 ] || exit 1
