# Missing upstream: a namespaced target. libjpeg-turbo builds jpeg-static and
# consumers write JPEG::JPEG or read JPEG_LIBRARIES.
cme_declare_port(
  NAME libjpeg-turbo
  PROVIDES JPEG libjpeg libjpeg-turbo
  VERSION 3.0.4
  GITHUB_REPOSITORY libjpeg-turbo/libjpeg-turbo
  GIT_TAG 3.0.4
  GIT_TAG_TEMPLATE "@VERSION@"
  LICENSE IJG BSD-3-Clause
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
)

function(cme_adapt_libjpeg-turbo source binary)
  cme_alias(JPEG::JPEG jpeg-static)
  cme_export_variable(JPEG JPEG_FOUND TRUE)
  cme_export_variable(JPEG JPEG_LIBRARY JPEG::JPEG)
  cme_export_variable(JPEG JPEG_LIBRARIES JPEG::JPEG)
  cme_export_variable(JPEG JPEG_INCLUDE_DIR "${source};${binary}")
  cme_export_variable(JPEG JPEG_INCLUDE_DIRS "${source};${binary}")
  cme_build_includes(jpeg-static "${source}" "${binary}")
endfunction()
