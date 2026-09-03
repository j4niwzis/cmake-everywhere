# Missing upstream: nothing, and that is the point. libjpeg-turbo refuses to
# be a subdirectory of another build, says so in as many words, and stops --
# an upstream build system cannot anticipate every downstream one and it
# would rather not try.
#
# So it is not made one. It is configured on its own, asked what it would
# build, and that is built here: in this graph, with this generator, beside
# everything else. IMPORT cmake, which is the same idea as the GN ports and
# for the same reason.
cme_declare_port(
  NAME libjpeg-turbo
  PROVIDES JPEG libjpeg libjpeg-turbo
  VERSION 3.0.4
  GITHUB_REPOSITORY libjpeg-turbo/libjpeg-turbo
  GIT_TAG 3.0.4
  GIT_TAG_TEMPLATE "@VERSION@"
  LICENSE IJG BSD-3-Clause
  IMPORT cmake
  IMPORT_TARGETS "jpeg-static=JPEG::JPEG"
  SYSTEM_PKGCONFIG "libjpeg:JPEG::JPEG"
  OPTIONS
    "ENABLE_SHARED OFF"
    "ENABLE_STATIC ON"
    "WITH_JAVA OFF"
    "WITH_TURBOJPEG ON"
  # What this library answers to when something asks the linker for it by
  # name. A bare -l finds whatever is installed; a target is an archive
  # with a path.
  LINK_NAMES
    "jpeg=JPEG::JPEG"
    "turbojpeg=JPEG::JPEG"
  # What a consumer links. Said here so that something other than a
  # human can check that the port still produces it.
  TARGETS JPEG::JPEG
)

function(cme_adapt_libjpeg-turbo source binary)
  # Its headers are the checkout and the directory it was configured in,
  # which is where jconfig.h was written.
  set(configured "${CMAKE_BINARY_DIR}/_cme/libjpeg-turbo-probe")
  target_include_directories(libjpeg-turbo_jpeg-static PUBLIC
    "$<BUILD_INTERFACE:${source}>" "$<BUILD_INTERFACE:${configured}>")
  cme_export_variable(JPEG JPEG_FOUND TRUE)
  cme_export_variable(JPEG JPEG_LIBRARY JPEG::JPEG)
  cme_export_variable(JPEG JPEG_LIBRARIES JPEG::JPEG)
  cme_export_variable(JPEG JPEG_INCLUDE_DIR "${source};${configured}")
  cme_export_variable(JPEG JPEG_INCLUDE_DIRS "${source};${configured}")
endfunction()
