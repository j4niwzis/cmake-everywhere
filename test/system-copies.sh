#!/bin/sh
# What a copy the system installed pulls in, and what it must not.
#
# A library taken from a prefix is found by its own config, and that config
# asks for what the library needs. Those asks arrive in the provider while the
# system is being asked about the library, and the provider steps aside for
# them: a piece of a system copy is answered the way the system would answer
# it, never by a build. Two things follow, and both are checked here.
#
# The pieces are still written down. Stepping aside once meant CMake found
# them and nothing reported it -- a consumer read that the library came from
# the system and nothing about the library under it.
#
# And a find module that asks for its own package again, as FindGTest does,
# does not loop: that loop is why the provider steps aside at all.
#
# Neither needs a compiler: the packages are imported targets and a config
# file, and every project here enables no language.
set -e
here=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$here")
work="${1:-$root/build/system-copies}"
failed=0
rm -rf "$work"
mkdir -p "$work"

provider="$work/provider.cmake"
echo "include(\"$root/cmake-everywhere.cmake\")" > "$provider"

configure() {
  name=$1; shift
  cmake -S "$work/$name" -B "$work/$name/build" -G Ninja \
    -DCMAKE_PROJECT_TOP_LEVEL_INCLUDES="$provider" \
    -DCMAKE_PREFIX_PATH="$work/prefix" -DCME_EXPORT_PORTS=OFF "$@" \
    > "$work/$name.log" 2>&1
}

ok()   { printf '  ok    %s\n' "$1"; }
fail() { printf '  FAIL  %s  (see %s)\n' "$1" "$2"; failed=$((failed + 1)); }

# A prefix with two libraries in it, the upper one needing the lower.
p="$work/prefix"
mkdir -p "$p/lib/cmake/lower" "$p/lib/cmake/upper" \
         "$p/share/cmake-everywhere/ports/lower" \
         "$p/share/cmake-everywhere/ports/upper"
cat > "$p/lib/cmake/lower/lowerConfig.cmake" <<'EOF'
if(NOT TARGET lower::lower)
  add_library(lower::lower INTERFACE IMPORTED)
endif()
EOF
printf 'set(PACKAGE_VERSION "0.1")\nset(PACKAGE_VERSION_COMPATIBLE TRUE)\n' \
  > "$p/lib/cmake/lower/lowerConfigVersion.cmake"
cat > "$p/lib/cmake/upper/upperConfig.cmake" <<'EOF'
include(CMakeFindDependencyMacro)
find_dependency(lower)
if(NOT TARGET upper::upper)
  add_library(upper::upper INTERFACE IMPORTED)
  set_target_properties(upper::upper PROPERTIES INTERFACE_LINK_LIBRARIES lower::lower)
endif()
EOF
printf 'set(PACKAGE_VERSION "0.1")\nset(PACKAGE_VERSION_COMPATIBLE TRUE)\n' \
  > "$p/lib/cmake/upper/upperConfigVersion.cmake"
cat > "$p/share/cmake-everywhere/ports/lower/port.cmake" <<'EOF'
cme_declare_port(NAME lower PROVIDES lower VERSION 0.1 LICENSE MIT
  GITHUB_REPOSITORY nobody/lower GIT_TAG main TARGETS lower::lower)
cme_installed_with(lower VERSION "0.1")
EOF
cat > "$p/share/cmake-everywhere/ports/upper/port.cmake" <<'EOF'
cme_declare_port(NAME upper PROVIDES upper VERSION 0.1 LICENSE MIT
  GITHUB_REPOSITORY nobody/upper GIT_TAG main DEPENDS lower TARGETS upper::upper)
cme_installed_with(upper VERSION "0.1")
EOF

# One: the library the system copy needs is reported, and once.
mkdir -p "$work/pieces"
cat > "$work/pieces/CMakeLists.txt" <<'EOF'
cmake_minimum_required(VERSION 3.28)
project(pieces NONE)
find_package(upper REQUIRED)
EOF
if configure pieces; then
  report="$work/pieces/build/cme-report.txt"
  if [ "$(grep -c '^upper system' "$report")" = 1 ] &&
     [ "$(grep -c '^lower system' "$report")" = 1 ]; then
    ok "a system copy and what it pulls in are both reported, once each"
  else
    fail "a system copy and what it pulls in are both reported, once each" "$report"
  fi
else
  fail "a system copy with a dependency configures" "$work/pieces.log"
fi

# Two: a find module that asks for its own package again does not loop.
mkdir -p "$p/lib/cmake/Loopy" "$p/share/cmake-everywhere/ports/loopy" \
         "$work/modules" "$work/loop"
printf 'set(Loopy_FOUND TRUE)\nset(Loopy_VERSION 1.0)\n' \
  > "$p/lib/cmake/Loopy/LoopyConfig.cmake"
cat > "$p/share/cmake-everywhere/ports/loopy/port.cmake" <<'EOF'
cme_declare_port(NAME loopy PROVIDES Loopy VERSION 1.0 LICENSE MIT
  GITHUB_REPOSITORY nobody/loopy GIT_TAG main)
cme_installed_with(loopy VERSION "1.0")
EOF
cat > "$work/modules/FindLoopy.cmake" <<'EOF'
find_package(Loopy CONFIG QUIET)
set(Loopy_FOUND TRUE)
EOF
cat > "$work/loop/CMakeLists.txt" <<EOF
cmake_minimum_required(VERSION 3.28)
project(loop NONE)
list(APPEND CMAKE_MODULE_PATH "$work/modules")
find_package(Loopy REQUIRED)
EOF
if configure loop; then
  ok "a find module asking for its own package again does not loop"
else
  fail "a find module asking for its own package again does not loop" "$work/loop.log"
fi

exit $failed
