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
  CHECK_HEADER zip.h
  OPTIONS
    # Its install rules name a target from another port -- zlib's -- and
    # CMake checks an install(EXPORT) even when the directory it is in is
    # EXCLUDE_FROM_ALL. A dependency does not install itself here anyway.
    "LIBZIP_DO_INSTALL OFF"
    # The C11 Annex K functions, which glibc and bionic both lack and which
    # libzip looks for by linking. A toolchain whose probes stop at an
    # archive -- which is every toolchain for a sysroot that cannot link an
    # executable, Android among them -- answers yes to every such question,
    # and the answer here is no on both counts.
    "HAVE_MEMCPY_S OFF"
    "HAVE_STRNCPY_S OFF"
    "HAVE_STRERROR_S OFF"
    "HAVE_STRERRORLEN_S OFF"
    # clonefile is macOS's, and asking for it by linking gets a yes from any
    # toolchain whose probes stop at an archive. Saying no here is saying
    # what Linux is: it has FICLONERANGE, which is a different question and
    # is asked separately.
    "HAVE_CLONEFILE OFF"
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
  # zip.h is in the tree and zipconf.h is written beside the build, both at
  # the top of their directory: configure_file(zipconf.h.in
  # ${PROJECT_BINARY_DIR}/zipconf.h). There is no zipconf directory and
  # never was -- naming one was a guess, and a guess that cost this library
  # its place in the store, because an entry is not published while
  # something it says it needs has never been written.
  cme_export_variable(libzip LIBZIP_INCLUDE_DIR "${source}/lib;${binary}")
  cme_export_variable(libzip LIBZIP_INCLUDE_DIRS "${source}/lib;${binary}")
endfunction()
