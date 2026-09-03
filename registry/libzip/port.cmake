# Missing upstream: dependencies resolved rather than assumed -- libzip looks
# for zlib with find_package and cannot be handed one.
cme_declare_port(
  NAME libzip
  PROVIDES libzip LIBZIP zip
  VERSION 1.11.2
  GITHUB_REPOSITORY nih-at/libzip
  GIT_TAG v1.11.2
  GIT_TAG_TEMPLATE "v@VERSION@"
  LICENSE BSD-3-Clause
  DEPENDS zlib
  SYSTEM_PKGCONFIG "libzip:libzip::zip"
  LINK_NAMES "zip=libzip::zip"
  TARGETS libzip::zip
  OPTIONS
    "BUILD_TOOLS OFF"
    "BUILD_REGRESS OFF"
    "BUILD_EXAMPLES OFF"
    "BUILD_DOC OFF"
    "ENABLE_COMMONCRYPTO OFF"
    "ENABLE_GNUTLS OFF"
    "ENABLE_MBEDTLS OFF"
    "ENABLE_OPENSSL OFF"
    "ENABLE_BZIP2 OFF"
    "ENABLE_LZMA OFF"
    "ENABLE_ZSTD OFF"
    # Seeded because the check for it is a compile test, and libzip must not
    # take the Darwin source on anything else.
    "HAVE_SYS_ATTR_H 0"
)

function(cme_adapt_libzip source binary)
  cme_alias(libzip::zip zip)
  cme_export_variable(libzip LIBZIP_FOUND TRUE)
  cme_export_variable(libzip LIBZIP_LIBRARY libzip::zip)
  cme_export_variable(libzip LIBZIP_LIBRARIES libzip::zip)
  cme_export_variable(libzip LIBZIP_INCLUDE_DIR
    "${source}/lib;${binary};${binary}/zipconf")
  cme_export_variable(libzip LIBZIP_INCLUDE_DIRS
    "${source}/lib;${binary};${binary}/zipconf")
endfunction()
