# Missing upstream: CMake, in the sense this registry means it -- Skia builds
# with GN, and its own GN-to-CMake script says it is "not meant for any
# purpose beyond development" in an IDE.
#
# So GN is asked to describe the build and the description becomes CMake
# targets: see cmake/gn.cmake, which knows nothing about Skia. Everything in
# this file is Skia's own vocabulary, and that is the only Skia-specific
# thing in the repository.
#
# Two rules shape what follows.
#
# Nothing by default. The port with no features is Skia as a CPU rasteriser:
# no GPU backend, no codecs, no fonts, no compression, no PDF, no SVG. A
# consumer asks for what it uses and gets a build of that, rather than paying
# for what somebody thought was a reasonable default.
#
# Nothing bundled, ever. Skia carries copies of zlib, libpng, libjpeg-turbo,
# libwebp, freetype, expat and more in third_party/externals, and every
# feature here that needs one of them turns on the matching
# skia_use_system_* and names the port that supplies it. Those settings are
# read back from GN afterwards rather than assumed. And since this build
# never runs Skia's dependency sync, third_party/externals is empty: a
# bundled path would not quietly happen, it would fail to find its sources.
cme_declare_port(
  NAME skia
  PROVIDES Skia skia SKIA
  VERSION 0.0.0
  GITHUB_REPOSITORY google/skia
  # Skia has no releases; it has milestone branches. A commit is what a port
  # can pin, and this one is a placeholder until a milestone is chosen
  # deliberately.
  GIT_TAG main
  GN_TARGETS "//:skia=Skia::skia"
  GN_ARGS
    "is_official_build=true"
    "is_component_build=false"
    "cc=\"@CC@\""
    "cxx=\"@CXX@\""
    "target_os=\"@TARGET_OS@\""
    "target_cpu=\"@TARGET_CPU@\""
    # No GPU. Ganesh and Graphite are both backends, and a backend is a
    # feature.
    "skia_enable_ganesh=false"
    "skia_enable_graphite=false"
    "skia_use_gl=false"
    "skia_use_egl=false"
    "skia_use_vulkan=false"
    "skia_use_metal=false"
    "skia_use_direct3d=false"
    "skia_use_dawn=false"
    "skia_use_webgl=false"
    "skia_use_webgpu=false"
    "skia_use_angle=false"
    "skia_use_x11=false"
    # No codecs.
    "skia_use_libpng_decode=false"
    "skia_use_libpng_encode=false"
    "skia_use_libjpeg_turbo_decode=false"
    "skia_use_libjpeg_turbo_encode=false"
    "skia_use_libwebp_decode=false"
    "skia_use_libwebp_encode=false"
    "skia_use_libavif=false"
    "skia_use_libjxl_decode=false"
    "skia_use_wuffs=false"
    "skia_use_dng_sdk=false"
    "skia_use_piex=false"
    "skia_use_ndk_images=false"
    # No fonts and no text shaping.
    "skia_use_freetype=false"
    "skia_use_fontconfig=false"
    "skia_use_fontations=false"
    "skia_use_harfbuzz=false"
    "skia_use_icu=false"
    "skia_use_bidi=false"
    "skia_enable_skunicode=false"
    # No compression, no document formats, no modules, no tools.
    "skia_use_zlib=false"
    "skia_use_expat=false"
    "skia_use_ffmpeg=false"
    "skia_use_lua=false"
    "skia_enable_pdf=false"
    "skia_enable_svg=false"
    "skia_enable_skottie=false"
    "skia_enable_tools=false"
    "extra_cflags=[@DEP_INCLUDES@]"
    "extra_ldflags=[@DEP_LIBDIRS@]"
  GN_CONFIRM
    "is_official_build=true"
)

# The names below are ours. Skia has no find_package convention to obey
# because nobody ever wrote one, so a consumer asks for "the Vulkan backend"
# rather than having to know it is spelled skia_use_vulkan.

cme_port_feature(skia gl
  SUMMARY "the Ganesh backend on OpenGL"
  GN_ARGS "skia_enable_ganesh=true" "skia_use_gl=true"
  GN_CONFIRM "skia_use_gl=true")

# EGL is a way of reaching GL, not an alternative to it.
cme_port_feature(skia egl
  SUMMARY "Ganesh on GL, reaching it through EGL"
  IMPLIES gl
  GN_ARGS "skia_use_egl=true"
  GN_CONFIRM "skia_use_egl=true")

cme_port_feature(skia vulkan
  SUMMARY "the Ganesh backend on Vulkan"
  GN_ARGS "skia_enable_ganesh=true" "skia_use_vulkan=true"
  GN_CONFIRM "skia_use_vulkan=true")

cme_port_feature(skia graphite
  SUMMARY "the Graphite backend"
  GN_ARGS "skia_enable_graphite=true")

# Each codec names the port that supplies it and the argument that makes Skia
# take it from there rather than from its own third_party copy.
cme_port_feature(skia png
  SUMMARY "PNG, through libpng"
  DEPENDS libpng
  GN_ARGS "skia_use_libpng_decode=true" "skia_use_libpng_encode=true"
          "skia_use_system_libpng=true"
  GN_CONFIRM "skia_use_system_libpng=true")

cme_port_feature(skia jpeg
  SUMMARY "JPEG, through libjpeg-turbo"
  DEPENDS libjpeg-turbo
  GN_ARGS "skia_use_libjpeg_turbo_decode=true"
          "skia_use_libjpeg_turbo_encode=true"
          "skia_use_system_libjpeg_turbo=true"
  GN_CONFIRM "skia_use_system_libjpeg_turbo=true")

cme_port_feature(skia webp
  SUMMARY "WebP, through libwebp"
  DEPENDS libwebp
  GN_ARGS "skia_use_libwebp_decode=true" "skia_use_libwebp_encode=true"
          "skia_use_system_libwebp=true"
  GN_CONFIRM "skia_use_system_libwebp=true")

cme_port_feature(skia zlib
  SUMMARY "deflate, which PDF and freetype both want"
  DEPENDS zlib
  GN_ARGS "skia_use_zlib=true" "skia_use_system_zlib=true"
  GN_CONFIRM "skia_use_system_zlib=true")

# FreeType reads compressed font tables, so it wants zlib whether or not
# anything else in the build does.
cme_port_feature(skia freetype
  SUMMARY "glyph rasterisation through FreeType"
  IMPLIES zlib
  DEPENDS freetype
  GN_ARGS "skia_use_freetype=true" "skia_use_system_freetype2=true"
          "skia_use_freetype_zlib_bundled=false"
  GN_CONFIRM "skia_use_system_freetype2=true")

# A font database is not a font rasteriser: fontconfig says which file, and
# FreeType turns it into glyphs.
cme_port_feature(skia fontconfig
  SUMMARY "finding fonts through the system's fontconfig"
  IMPLIES freetype
  GN_ARGS "skia_use_fontconfig=true" "skia_enable_fontmgr_fontconfig=true"
  GN_CONFIRM "skia_use_fontconfig=true")

cme_port_feature(skia fontmgr-directory
  SUMMARY "loading fonts from a directory, with no system font database"
  IMPLIES freetype
  GN_ARGS "skia_enable_fontmgr_custom_directory=true")

# PDF streams are deflated, so this is zlib whether it was asked for or not.
cme_port_feature(skia pdf
  SUMMARY "the PDF backend"
  IMPLIES zlib
  GN_ARGS "skia_enable_pdf=true"
  GN_CONFIRM "skia_enable_pdf=true")

cme_port_feature(skia svg
  SUMMARY "the SVG module, which reads XML with expat"
  DEPENDS expat
  GN_ARGS "skia_enable_svg=true" "skia_use_expat=true"
          "skia_use_system_expat=true"
  GN_CONFIRM "skia_use_system_expat=true")

cme_port_feature(skia skottie
  SUMMARY "the Lottie animation module"
  GN_ARGS "skia_enable_skottie=true")

function(cme_adapt_skia source binary)
  cme_export_variable(Skia SKIA_FOUND TRUE)
  cme_export_variable(Skia SKIA_LIBRARY Skia::skia)
  cme_export_variable(Skia SKIA_LIBRARIES Skia::skia)
  cme_export_variable(Skia SKIA_INCLUDE_DIR "${source}")
  cme_export_variable(Skia SKIA_INCLUDE_DIRS "${source}")
  # Skia is included as "include/core/SkCanvas.h", from the root of its own
  # checkout, which is why the root is the include directory.
  target_include_directories(skia_skia INTERFACE
    "$<BUILD_INTERFACE:${source}>")
endfunction()
