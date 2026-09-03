# Missing upstream: dependencies resolved rather than assumed. FreeType looks
# for zlib and libpng with find_package and has no way to be handed either.
cme_declare_port(
  NAME freetype
  PROVIDES Freetype freetype FREETYPE
  VERSION 2.13.3
  GIT_REPOSITORY https://gitlab.freedesktop.org/freetype/freetype.git
  GIT_TAG VER-2-13-3
  # Upstream tags VER-2-13-3, so a version is rewritten to reach one.
  GIT_TAG_TEMPLATE "VER-@VERSION_DASH@"
  LICENSE FTL GPL-2.0-or-later
  DEPENDS zlib
  SYSTEM_PKGCONFIG "freetype2:Freetype::Freetype"
  OPTIONS
    "SKIP_INSTALL_ALL ON"
    "FT_DISABLE_HARFBUZZ ON"
    "FT_DISABLE_BROTLI ON"
    "FT_DISABLE_BZIP2 ON"
    "FT_REQUIRE_ZLIB ON"
    "FT_DISABLE_PNG ON"
)

# Colour bitmap glyphs are PNGs inside the font file, and reading them is the
# only reason FreeType wants libpng.
cme_port_feature(freetype png
  SUMMARY "colour bitmap glyphs, which are PNG inside the font"
  DEPENDS libpng
  OPTIONS "FT_DISABLE_PNG OFF" "FT_REQUIRE_PNG ON")

function(cme_adapt_freetype source binary)
  cme_alias(Freetype::Freetype freetype)
  cme_export_variable(Freetype FREETYPE_FOUND TRUE)
  cme_export_variable(Freetype FREETYPE_LIBRARY Freetype::Freetype)
  cme_export_variable(Freetype FREETYPE_LIBRARIES Freetype::Freetype)
  cme_export_variable(Freetype FREETYPE_INCLUDE_DIRS
    "${source}/include;${binary}/include")
  cme_export_variable(Freetype FREETYPE_INCLUDE_DIR_ft2build
    "${source}/include")
  cme_export_variable(Freetype FREETYPE_INCLUDE_DIR_freetype2
    "${source}/include")
endfunction()
