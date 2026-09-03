# Missing upstream: a namespaced target and an exported config. zlib builds
# zlibstatic and leaves every consumer to guess.
cme_declare_port(
  NAME zlib
  PROVIDES ZLIB
  VERSION 1.3.1
  GITHUB_REPOSITORY madler/zlib
  GIT_TAG v1.3.1
  OPTIONS
    "SKIP_INSTALL_ALL ON"
    "ZLIB_BUILD_EXAMPLES OFF"
  SYSTEM_PKGCONFIG "zlib:ZLIB::ZLIB"
  GIT_TAG_TEMPLATE "v@VERSION@"
  LICENSE Zlib
)

# zlib's own CMake builds targets called zlib and zlibstatic and offers no
# namespaced name at all, while everything that looks for it expects
# ZLIB::ZLIB and the variables FindZLIB sets. Both spellings of the include
# and library variables are exported: FindZLIB sets the plural ones, and a
# good deal of third-party CMake reads the singular ones instead.
function(cme_adapt_zlib source binary)
  cme_alias(ZLIB::ZLIB zlibstatic)
  cme_export_variable(ZLIB ZLIB_FOUND TRUE)
  cme_export_variable(ZLIB ZLIB_LIBRARY ZLIB::ZLIB)
  cme_export_variable(ZLIB ZLIB_LIBRARIES ZLIB::ZLIB)
  # zconf.h is generated, so the build directory is part of the answer.
  cme_export_variable(ZLIB ZLIB_INCLUDE_DIR "${source};${binary}")
  cme_export_variable(ZLIB ZLIB_INCLUDE_DIRS "${source};${binary}")
  cme_export_variable(ZLIB ZLIB_VERSION 1.3.1)
  cme_export_variable(ZLIB ZLIB_VERSION_STRING 1.3.1)
  cme_build_includes(zlibstatic "${source}" "${binary}")
endfunction()
