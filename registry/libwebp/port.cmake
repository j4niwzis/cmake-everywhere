# Missing upstream: nothing serious. libwebp ships CMake and exports
# WebP::webp; the variables are here for what predates that.
cme_declare_port(
  NAME libwebp
  PROVIDES WebP libwebp webp
  VERSION 1.4.0
  GITHUB_REPOSITORY webmproject/libwebp
  GIT_TAG v1.4.0
  GIT_TAG_TEMPLATE "v@VERSION@"
  LICENSE BSD-3-Clause
  SYSTEM_PKGCONFIG "libwebp:WebP::webp"
  OPTIONS
    "WEBP_BUILD_ANIM_UTILS OFF"
    "WEBP_BUILD_CWEBP OFF"
    "WEBP_BUILD_DWEBP OFF"
    "WEBP_BUILD_GIF2WEBP OFF"
    "WEBP_BUILD_IMG2WEBP OFF"
    "WEBP_BUILD_VWEBP OFF"
    "WEBP_BUILD_WEBPINFO OFF"
    "WEBP_BUILD_WEBPMUX OFF"
    "WEBP_BUILD_EXTRAS OFF"
)

function(cme_adapt_libwebp source binary)
  cme_alias(WebP::webp webp)
  cme_export_variable(WebP WebP_FOUND TRUE)
  cme_export_variable(WebP WEBP_FOUND TRUE)
  cme_export_variable(WebP WEBP_LIBRARIES WebP::webp)
  cme_export_variable(WebP WEBP_INCLUDE_DIRS "${source}/src")
  cme_export_variable(WebP WEBP_INCLUDE_DIR "${source}/src")
endfunction()
