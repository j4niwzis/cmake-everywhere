# Missing upstream: nothing, and that is the point. libjpeg-turbo refuses to
# be a subdirectory of another build, says so in as many words, and stops --
# an upstream build system cannot anticipate every downstream one and it
# would rather not try. So it is configured, built and installed on its own,
# which is what EXTERNAL means here.
cme_declare_port(
  NAME libjpeg-turbo
  PROVIDES JPEG libjpeg libjpeg-turbo
  VERSION 3.0.4
  GITHUB_REPOSITORY libjpeg-turbo/libjpeg-turbo
  GIT_TAG 3.0.4
  GIT_TAG_TEMPLATE "@VERSION@"
  LICENSE IJG BSD-3-Clause
  EXTERNAL YES
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
  set(prefix "${CME_INSTALLED_libjpeg-turbo}")
  cme_installed_library(JPEG::JPEG "${prefix}" "libjpeg.a")
  cme_export_variable(JPEG JPEG_FOUND TRUE)
  cme_export_variable(JPEG JPEG_LIBRARY JPEG::JPEG)
  cme_export_variable(JPEG JPEG_LIBRARIES JPEG::JPEG)
  cme_export_variable(JPEG JPEG_INCLUDE_DIR "${prefix}/include")
  cme_export_variable(JPEG JPEG_INCLUDE_DIRS "${prefix}/include")
endfunction()
