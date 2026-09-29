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

# Three: a config not written to be read twice -- it makes its targets with
# no guard, as HarfBuzz's does -- is read once. The provider looks at the
# copy before it answers with it; answering by reading it again was an
# error about targets that exist. And what the config sets reaches every
# caller: the first, and one in a directory of its own.
mkdir -p "$p/lib/cmake/unguarded" "$p/share/cmake-everywhere/ports/unguarded" \
         "$work/once/sub"
cat > "$p/lib/cmake/unguarded/unguardedConfig.cmake" <<'EOF'
add_library(unguarded::unguarded INTERFACE IMPORTED)
set(unguarded_WORDS "read;once")
EOF
printf 'set(PACKAGE_VERSION "2.0")\nset(PACKAGE_VERSION_COMPATIBLE TRUE)\n' \
  > "$p/lib/cmake/unguarded/unguardedConfigVersion.cmake"
cat > "$p/share/cmake-everywhere/ports/unguarded/port.cmake" <<'EOF'
cme_declare_port(NAME unguarded PROVIDES unguarded VERSION 2.0 LICENSE MIT
  GITHUB_REPOSITORY nobody/unguarded GIT_TAG main TARGETS unguarded::unguarded)
cme_installed_with(unguarded VERSION "2.0")
EOF
cat > "$work/once/CMakeLists.txt" <<'EOF'
cmake_minimum_required(VERSION 3.28)
project(once NONE)
find_package(unguarded REQUIRED)
if(NOT unguarded_WORDS STREQUAL "read;once" OR NOT TARGET unguarded::unguarded)
  message(FATAL_ERROR "the first caller has [${unguarded_WORDS}]")
endif()
find_package(unguarded REQUIRED)
add_subdirectory(sub)
EOF
cat > "$work/once/sub/CMakeLists.txt" <<'EOF'
find_package(unguarded REQUIRED)
if(NOT unguarded_WORDS STREQUAL "read;once" OR NOT unguarded_FOUND)
  message(FATAL_ERROR "a caller in a directory of its own has [${unguarded_WORDS}]")
endif()
EOF
if configure once; then
  ok "a config that cannot be read twice is read once, and what it sets reaches every caller"
else
  fail "a config that cannot be read twice is read once, and what it sets reaches every caller" "$work/once.log"
fi

# Four and five: a library built from source, with an older description of
# it installed. The library declares itself in its own CMakeLists -- its
# features with cme_port_feature, its port with GIT_TAG main -- the way skiff
# does, and the description a copy of it left in the prefix declares no
# features and another commit. The project pins a commit and asks for a
# component. The registry is read before the project declares the port, as it
# is in any project that asked for something else first, so the installed
# description is the first to name it.
#
# Four: the component reaches the library. The installed port file made the
# port look described by somebody else, and an asked name it did not declare
# was read as another library's component and dropped: built [].
#
# Five: the pin stays the project's. The library's own GIT_TAG main was heard
# as the project and replaced it, and with no commit left to compare, an
# installed copy of another revision could be taken beside the one built.
lib="$work/selfish-src"
mkdir -p "$lib" "$p/share/cmake-everywhere/ports/selfish" "$work/selfish"
cat > "$lib/CMakeLists.txt" <<'EOF'
cmake_minimum_required(VERSION 3.28)
project(selfish NONE)
if(COMMAND cme_port_feature)
  cme_port_feature(selfish shiny SUMMARY "asked for as a component")
endif()
set_property(GLOBAL PROPERTY SELFISH_BUILT_WITH "${CME_FEATURES_selfish}")
add_library(selfish INTERFACE)
add_library(selfish::selfish ALIAS selfish)
if(COMMAND cme_declare_port)
  cme_declare_port(NAME selfish PROVIDES selfish VERSION 1.0 LICENSE MIT
    GITHUB_REPOSITORY nobody/selfish GIT_TAG main TARGETS selfish::selfish)
endif()
EOF
(cd "$lib" && git init -q && git add . &&
 git -c user.name=test -c user.email=test@test commit -qm selfish)
rev=$(cd "$lib" && git rev-parse HEAD)
cat > "$p/share/cmake-everywhere/ports/selfish/port.cmake" <<EOF
cme_declare_port(NAME selfish PROVIDES selfish VERSION 0.9 LICENSE MIT
  GIT_REPOSITORY "$lib" GIT_TAG 1111111111111111111111111111111111111111
  TARGETS selfish::selfish)
EOF
cat > "$work/selfish/CMakeLists.txt" <<EOF
cmake_minimum_required(VERSION 3.28)
project(selfish_user NONE)
cme_load_registry()
cme_declare_port(NAME selfish PROVIDES selfish
  GIT_REPOSITORY "$lib" GIT_TAG $rev SYSTEM NEVER)
find_package(selfish COMPONENTS shiny REQUIRED)
get_property(built_with GLOBAL PROPERTY SELFISH_BUILT_WITH)
get_property(pin GLOBAL PROPERTY CME_PORT_selfish_GIT_TAG)
file(WRITE "\${CMAKE_BINARY_DIR}/selfish.txt" "with=\${built_with}\npin=\${pin}\n")
EOF
if configure selfish; then
  said="$work/selfish/build/selfish.txt"
  if grep -q '^with=.*shiny' "$said"; then
    ok "a component asked of a library reaches it past an installed description that lacks it"
  else
    fail "a component asked of a library reaches it past an installed description that lacks it" "$said"
  fi
  if grep -qx "pin=$rev" "$said"; then
    ok "a library declaring itself GIT_TAG main does not replace the project's pin"
  else
    fail "a library declaring itself GIT_TAG main does not replace the project's pin" "$said"
  fi
else
  fail "a library with an older description installed configures" "$work/selfish.log"
fi

# Six: the defines an installed Skia is used with are the copy's own. Skia's
# headers are cut by SK_GANESH and SK_CODEC_DECODES_*, and nothing installed
# records which were on, so they were worked out from what was asked -- by
# whichever ask came first. skiff's description asked for png and jpeg
# before skiff asked for gl, and a machine's Skia with both was used with no
# defines at all: no pictures decoded, and GL compiled out. A Skia with only
# a PNG decoder, asked for gl, png and gif, is used with the PNG defines and
# nothing else.
fs="$work/fakeskia"
mkdir -p "$fs/include/skia/codec" "$fs/include/skia/core" "$work/defines"
: > "$fs/include/skia/core/SkCanvas.h"
cat > "$fs/include/skia/codec/SkPngDecoder.h" <<'EOF'
#pragma once
#include <memory>
template <class T> struct sk_sp { T* p = nullptr; };
struct SkData {};
struct SkCodec { enum Result { kSuccess }; };
namespace SkCodecs { using DecodeContext = void*; }
namespace SkPngDecoder {
std::unique_ptr<SkCodec> Decode(sk_sp<const SkData>, SkCodec::Result*, SkCodecs::DecodeContext);
}
EOF
# And a GIF decoder declared and not built: a header is there whether or not
# the feature was, and only a link can tell. At -O2 a probe taking the
# address to compare with nullptr had the comparison folded away and linked
# regardless, so the build here is optimised on purpose.
cat > "$fs/include/skia/codec/SkGifDecoder.h" <<'EOF'
#pragma once
#include <skia/codec/SkPngDecoder.h>
namespace SkGifDecoder {
std::unique_ptr<SkCodec> Decode(sk_sp<const SkData>, SkCodec::Result*, SkCodecs::DecodeContext);
}
EOF
cat > "$fs/png.cc" <<'EOF'
#include <skia/codec/SkPngDecoder.h>
std::unique_ptr<SkCodec> SkPngDecoder::Decode(sk_sp<const SkData>, SkCodec::Result*, SkCodecs::DecodeContext) { return nullptr; }
EOF
cat > "$work/defines/CMakeLists.txt" <<EOF
cmake_minimum_required(VERSION 3.28)
project(defines LANGUAGES CXX)
try_compile(built PROJECT fakeskia SOURCE_DIR "$fs/lib" BINARY_DIR "$fs/build")
add_library(fakeskia STATIC IMPORTED)
set_target_properties(fakeskia PROPERTIES IMPORTED_LOCATION "$fs/build/libfakeskia.a")
cme_load_registry()
cme_features(skia gl png gif)
cme_adapt_skia_system("$fs/include/skia;$fs/include" fakeskia)
get_target_property(defines fakeskia INTERFACE_COMPILE_DEFINITIONS)
file(WRITE "\${CMAKE_BINARY_DIR}/defines.txt" "\${defines}")
EOF
mkdir -p "$fs/lib"
cat > "$fs/lib/CMakeLists.txt" <<EOF
cmake_minimum_required(VERSION 3.28)
project(fakeskia LANGUAGES CXX)
add_library(fakeskia STATIC "$fs/png.cc")
target_include_directories(fakeskia PRIVATE "$fs/include")
set_target_properties(fakeskia PROPERTIES ARCHIVE_OUTPUT_DIRECTORY "$fs/build")
EOF
if CXXFLAGS=-O2 configure defines; then
  said="$work/defines/build/defines.txt"
  if [ "$(cat "$said")" = "SK_CODEC_DECODES_PNG;SK_CODEC_ENCODES_PNG" ]; then
    ok "an installed Skia is used with the defines of what it was built with"
  else
    fail "an installed Skia is used with the defines of what it was built with" "$said"
  fi
else
  fail "an installed Skia's defines are asked of the copy" "$work/defines.log"
fi

exit $failed
