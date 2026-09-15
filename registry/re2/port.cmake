# Missing upstream: nothing but the dependency. re2 ships CMake, exports
# re2::re2 and installs a re2.pc; what it does not do is fetch Abseil, which it
# has required since 2023 and expects to find already answered for.
#
# Which is the whole reason this port names a dependency at all: a build that
# asks for re2 and nothing else still needs absl, and finding that out from the
# linker is finding it out late.
cme_declare_port(
  NAME re2
  PROVIDES re2
  VERSION 2024-07-02
  GITHUB_REPOSITORY google/re2
  GIT_TAG 2024-07-02
  GIT_TAG_TEMPLATE "@VERSION@"
  DEPENDS absl
  OPTIONS
    "RE2_BUILD_TESTING OFF"
    "BUILD_TESTING OFF"
  SYSTEM_PKGCONFIG "re2:re2::re2"
  LICENSE BSD-3-Clause
  LINK_NAMES
    "re2=re2::re2"
  TARGETS re2::re2
  CHECK_HEADER re2/re2.h
)
