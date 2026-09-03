# Text shaping: which glyph, where, for a run of characters in a script.
#
# Missing upstream: nothing, and that is the point of this port. HarfBuzz
# ships CMake and installs harfbuzzConfig with harfbuzz:: targets, so a
# machine that has it is used and a machine that has not builds it the same
# way as everything else here.
#
# What it is built with, and why so little of it: the shapers for macOS and
# Windows are the systems' own and belong to a build for those systems, glib
# and ICU are Unicode function providers that a consumer chooses rather than
# inherits, and cairo and GObject are for drawing and for bindings. What is
# left is the shaper itself, which is what a program that lays out text asks
# for.
cme_declare_port(
  NAME harfbuzz
  PROVIDES harfbuzz HarfBuzz
  VERSION 14.4.0
  GITHUB_REPOSITORY harfbuzz/harfbuzz
  GIT_TAG 14.4.0
  GIT_TAG_TEMPLATE "@VERSION@"
  SYSTEM_PKGCONFIG "harfbuzz:harfbuzz::harfbuzz"
  OPTIONS
    "BUILD_SHARED_LIBS OFF"
    "HB_BUILD_UTILS OFF"
    "HB_HAVE_GLIB OFF"
    "HB_HAVE_ICU OFF"
    "HB_HAVE_CAIRO OFF"
    "HB_HAVE_GOBJECT OFF"
    "HB_HAVE_INTROSPECTION OFF"
    "HB_HAVE_CORETEXT OFF"
    "HB_HAVE_DIRECTWRITE OFF"
    "HB_HAVE_UNISCRIBE OFF"
    "HB_HAVE_GDI OFF"
    # Rasterising and drawing are not what this is taken for here, and each
    # is a dependency of its own.
    "HB_BUILD_RASTER OFF"
    "HB_BUILD_VECTOR OFF"
    "HB_BUILD_GPU OFF"
  LICENSE MIT
  LINK_NAMES
    "harfbuzz=harfbuzz::harfbuzz"
    "harfbuzz-subset=harfbuzz::harfbuzz-subset"
  TARGETS harfbuzz::harfbuzz
  CHECK_HEADER harfbuzz/hb.h
)

# Reading faces through FreeType, which is how everything that already has a
# FreeType face hands it over. Without it a caller has to load the font a
# second time, with HarfBuzz's own reader.
cme_port_feature(harfbuzz freetype
  SUMMARY "hb_ft_font_create and the rest of the FreeType interoperation"
  DEFAULT YES
  DEPENDS freetype
  OPTIONS "HB_HAVE_FREETYPE ON"
  SYSTEM_CODE "#include <harfbuzz/hb-ft.h>
int main() {
  hb_font_t *(*fn)(FT_Face, hb_destroy_func_t) = &hb_ft_font_create;
  return fn == nullptr;
}")

# The part that makes a smaller font out of a larger one, which is what a
# document format wants and a screen does not.
cme_port_feature(harfbuzz subset
  SUMMARY "harfbuzz-subset, for writing out only the glyphs a document uses"
  DEFAULT YES
  OPTIONS "HB_BUILD_SUBSET ON")

function(cme_adapt_harfbuzz source binary)
  cme_alias(harfbuzz::harfbuzz harfbuzz)
  if(TARGET harfbuzz-subset)
    cme_alias(harfbuzz::harfbuzz-subset harfbuzz-subset)
  endif()
  # HarfBuzz's headers are installed into a harfbuzz/ directory, and a build
  # that reads them from the source tree finds them in src/ with no such
  # prefix. What every consumer writes is <harfbuzz/hb.h>.
  cme_header_prefix(named harfbuzz "${source}/src")
  target_include_directories(harfbuzz INTERFACE "$<BUILD_INTERFACE:${named}>")
  cme_export_variable(harfbuzz harfbuzz_FOUND TRUE)
  cme_export_variable(harfbuzz HARFBUZZ_FOUND TRUE)
  cme_export_variable(harfbuzz HARFBUZZ_LIBRARIES harfbuzz::harfbuzz)
  cme_export_variable(harfbuzz HARFBUZZ_INCLUDE_DIRS "${named}")
endfunction()
