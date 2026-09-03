# Missing upstream: nothing much. HarfBuzz builds with CMake as well as with
# meson, and the CMake build is a subdirectory of another one without
# complaint -- so it is one here.
#
# It is here because Skia's text shaping is HarfBuzz: skia_use_harfbuzz, and
# skshaper and skparagraph above it. A build that only draws glyphs it laid
# out itself needs none of this, which is why Skia's port asks for it as a
# feature rather than always.
cme_declare_port(
  NAME harfbuzz
  PROVIDES harfbuzz HarfBuzz
  VERSION 10.1.0
  GITHUB_REPOSITORY harfbuzz/harfbuzz
  GIT_TAG 10.1.0
  GIT_TAG_TEMPLATE "@VERSION@"
  LICENSE MIT
  DEPENDS freetype
  SYSTEM_PKGCONFIG "harfbuzz:harfbuzz::harfbuzz"
  LINK_NAMES "harfbuzz=harfbuzz::harfbuzz"
  TARGETS harfbuzz::harfbuzz
  CHECK_HEADER harfbuzz/hb.h
  # Shaping and nothing else: no utilities, no tests, no documentation, and
  # no ICU inside HarfBuzz -- what needs Unicode data here is Skia, which
  # asks ICU for it directly.
  OPTIONS
    "HB_HAVE_FREETYPE ON"
    "HB_HAVE_ICU OFF"
    "HB_HAVE_GLIB OFF"
    "HB_HAVE_GOBJECT OFF"
    "HB_BUILD_UTILS OFF"
    "HB_BUILD_TESTS OFF"
    "HB_BUILD_SUBSET ON"
    "BUILD_TESTING OFF"
    "SKIP_INSTALL_ALL ON"
)

function(cme_adapt_harfbuzz source binary)
  cme_alias(harfbuzz::harfbuzz harfbuzz)
  # Its headers are src/hb.h in the checkout and harfbuzz/hb.h once
  # installed, and both spellings are written in the wild.
  cme_header_prefix(root harfbuzz "${source}/src")
  target_include_directories(harfbuzz INTERFACE
    "$<BUILD_INTERFACE:${root}>" "$<BUILD_INTERFACE:${source}/src>")
  cme_export_variable(harfbuzz harfbuzz_FOUND TRUE)
  cme_export_variable(harfbuzz HARFBUZZ_LIBRARIES harfbuzz::harfbuzz)
  cme_export_variable(harfbuzz HARFBUZZ_INCLUDE_DIRS "${root};${source}/src")
endfunction()
