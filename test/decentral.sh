#!/bin/sh
# Whether a library can be used without asking anybody.
#
# This is the case the whole thing is for. A library exists, it is in a git
# repository somewhere, and a project wants it today. Nothing here is in the
# registry, nothing was merged anywhere, and no index was asked: the upstream
# repository is made by this script a minute before it is used.
#
# Three ways to say where a port comes from, and all three have to work:
# written into the project itself, read from a directory of ports, and read
# from a repository of ports named by its URL.
set -e
here=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$here")
provider="$root/cmake-everywhere.cmake"
work="${1:-$root/build/decentral-check}"
failed=0

if ! command -v git >/dev/null 2>&1; then
  printf '  skip  decentral (no git)\n'
  exit 0
fi

rm -rf "$work"
mkdir -p "$work"

# The upstream library. A CMakeLists, a header, a source, a tag. It knows
# nothing about any of this.
mkdir -p "$work/upstream/include/hello"
cat >"$work/upstream/CMakeLists.txt" <<'EOF'
cmake_minimum_required(VERSION 3.24)
project(hello LANGUAGES CXX)
add_library(hello STATIC hello.cc)
target_include_directories(hello PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/include")
add_library(Hello::Hello ALIAS hello)
EOF
cat >"$work/upstream/hello.cc" <<'EOF'
#include <hello/hello.h>
int hello_answer() { return 42; }
EOF
cat >"$work/upstream/include/hello/hello.h" <<'EOF'
#pragma once
int hello_answer();
EOF
(
  cd "$work/upstream"
  git init -q .
  git add -A
  git -c user.email=nobody@example -c user.name=nobody commit -qm "hello"
  git tag v1.0.0
)

port_text() {
  cat <<EOF
cme_declare_port(
  NAME hello
  PROVIDES Hello
  VERSION 1.0.0
  GIT_REPOSITORY "file://$work/upstream"
  GIT_TAG v1.0.0
)
EOF
}

# The same port said three ways.
port_text >"$work/declare.cmake"
mkdir -p "$work/overlay/hello" "$work/overlay/beta"
port_text >"$work/overlay/hello/port.cmake"
# And a port the registry also has, to see which one is read.
cat >"$work/overlay/beta/port.cmake" <<'EOF'
cme_declare_port(NAME beta PROVIDES Beta VERSION 9.9.9
  GITHUB_REPOSITORY nobody/beta GIT_TAG v9.9.9)
EOF
cp -r "$work/overlay" "$work/overlay-repo"
(
  cd "$work/overlay-repo"
  git init -q .
  git add -A
  git -c user.email=nobody@example -c user.name=nobody commit -qm "ports"
)

configure() {
  name=$1
  shift
  cmake -S "$here/port" -B "$work/$name" -G Ninja \
    -DCMAKE_PROJECT_TOP_LEVEL_INCLUDES="$provider" \
    -DCME_REGISTRY="$here/registry" \
    -DCME_STORE="$work/store" \
    -DCME_SYSTEM=NEVER \
    -DCME_PORT_PACKAGE=Hello \
    -DCME_PORT_TARGETS=Hello::Hello \
    "$@" >"$work/$name.log" 2>&1 &&
    cmake --build "$work/$name" >>"$work/$name.log" 2>&1
}

# A second library, which needs the first. Its own tree says where the first
# comes from, so a project that uses this one says nothing about that one.
mkdir -p "$work/world"
cat >"$work/world/CMakeLists.txt" <<'EOF'
cmake_minimum_required(VERSION 3.24)
project(world LANGUAGES CXX)
find_package(Hello REQUIRED)
add_library(world STATIC world.cc)
target_link_libraries(world PUBLIC Hello::Hello)
add_library(World::World ALIAS world)
EOF
cat >"$work/world/world.cc" <<'EOF'
#include <hello/hello.h>
int world_answer() { return hello_answer(); }
EOF
port_text >"$work/world/cme-ports.cmake"
(
  cd "$work/world"
  git init -q .
  git add -A
  git -c user.email=nobody@example -c user.name=nobody commit -qm "world"
  git tag v1.0.0
)
cat >"$work/declare-world.cmake" <<EOF
cme_declare_port(
  NAME world
  PROVIDES World
  VERSION 1.0.0
  GIT_REPOSITORY "file://$work/world"
  GIT_TAG v1.0.0
)
EOF

# A project whose whole purpose is to have declared something, so that
# installing it installs what it declared.
mkdir -p "$work/exporter"
cat >"$work/exporter/CMakeLists.txt" <<EOF
cmake_minimum_required(VERSION 3.24)
project(exporter LANGUAGES CXX)
cme_declare_port(
  NAME hello
  PROVIDES Hello
  VERSION 1.0.0
  GIT_REPOSITORY "file://$work/upstream"
  GIT_TAG v1.0.0
)
EOF

check() {
  if [ "$2" = 0 ]; then
    printf '  ok    %s\n' "$1"
  else
    printf '  FAIL  %s  (see %s)\n' "$1" "$3"
    failed=$((failed + 1))
  fi
}

# One: the project carries the port itself. No registry entry, no overlay,
# no directory of ports at all -- four lines in a CMakeLists.
configure inline -DCME_PORT_DECLARE="$work/declare.cmake" && code=0 || code=1
check "a port the project declares itself" "$code" "$work/inline.log"

# Two: a directory of ports someone else keeps.
configure overlay-directory -DCME_OVERLAYS="$work/overlay" && code=0 || code=1
check "a port from an overlay directory" "$code" "$work/overlay-directory.log"

# The overlay and the registry both have beta. The overlay is read.
if grep -qF "beta comes from the overlay" "$work/overlay-directory.log"; then
  printf '  ok    %s\n' "an overlay port keeps the registry's out"
else
  printf '  FAIL  %s  (see %s)\n' "an overlay port keeps the registry's out" \
    "$work/overlay-directory.log"
  failed=$((failed + 1))
fi

# Three: a repository of ports, named by URL and cloned. This is what
# publishing a port looks like when nobody has to accept it.
configure overlay-repository \
  -DCME_OVERLAYS="file://$work/overlay-repo" \
  -DCME_OVERLAY_CACHE="$work/overlays" && code=0 || code=1
check "a port from an overlay repository" "$code" \
  "$work/overlay-repository.log"

# Four: the library says what it needs, and the project using it does not.
# Nothing here mentions hello except the world repository itself.
configure carried \
  -DCME_PORT_DECLARE="$work/declare-world.cmake" \
  -DCME_PORT_PACKAGE=World -DCME_PORT_TARGETS=World::World && code=0 || code=1
check "a library carrying the ports for what it needs" "$code" \
  "$work/carried.log"

if grep -qF "carries" "$work/carried.log"; then
  printf '  ok    %s\n' "and it says which file it read"
else
  printf '  FAIL  %s  (see %s)\n' "and it says which file it read" \
    "$work/carried.log"
  failed=$((failed + 1))
fi

# Five: installed, and then read from the prefix by a project that declares
# nothing at all. This is the one that answers "is it here already" without
# cloning anything.
if cmake -S "$work/exporter" -B "$work/export" -G Ninja \
     -DCMAKE_PROJECT_TOP_LEVEL_INCLUDES="$provider" \
     -DCME_REGISTRY="$here/registry" >"$work/export.log" 2>&1 &&
   cmake --install "$work/export" --prefix "$work/prefix" \
     >>"$work/export.log" 2>&1 &&
   [ -f "$work/prefix/share/cmake-everywhere/ports/hello/port.cmake" ]; then
  printf '  ok    %s\n' "a project installs the ports it declared"
else
  printf '  FAIL  %s  (see %s)\n' "a project installs the ports it declared" \
    "$work/export.log"
  failed=$((failed + 1))
fi

configure from-the-system -DCMAKE_PREFIX_PATH="$work/prefix" && code=0 || code=1
check "a port read from a prefix, by a project that declares nothing" \
  "$code" "$work/from-the-system.log"

[ "$failed" = 0 ]
