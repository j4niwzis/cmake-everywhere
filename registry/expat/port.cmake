# Missing upstream: nothing much. libexpat ships CMake and exports
# expat::expat; this port exists so that something asking for EXPAT gets it
# built rather than only found.
cme_declare_port(
  NAME expat
  PROVIDES EXPAT expat
  VERSION 2.6.4
  GITHUB_REPOSITORY libexpat/libexpat
  GIT_TAG R_2_6_4
  # Upstream tags R_2_6_4, so a version has to be rewritten to reach one.
  GIT_TAG_TEMPLATE "R_@VERSION_UNDERSCORE@"
  SOURCE_SUBDIR expat
  SYSTEM_PKGCONFIG "expat:EXPAT::EXPAT"
  OPTIONS
    "EXPAT_BUILD_TOOLS OFF"
    "EXPAT_BUILD_EXAMPLES OFF"
    "EXPAT_BUILD_TESTS OFF"
    "EXPAT_BUILD_DOCS OFF"
    "EXPAT_SHARED_LIBS OFF"
  LICENSE MIT
  # What this library answers to when something asks the linker for it by
  # name. A bare -l finds whatever is installed; a target is an archive
  # with a path.
  LINK_NAMES
    "expat=EXPAT::EXPAT"
  # What a consumer links. Said here so that something other than a
  # human can check that the port still produces it.
  TARGETS EXPAT::EXPAT
)

function(cme_adapt_expat source binary)
  cme_alias(EXPAT::EXPAT expat)
  cme_export_variable(EXPAT EXPAT_FOUND TRUE)
  cme_export_variable(EXPAT EXPAT_LIBRARY EXPAT::EXPAT)
  cme_export_variable(EXPAT EXPAT_LIBRARIES EXPAT::EXPAT)
  cme_export_variable(EXPAT EXPAT_INCLUDE_DIR "${source}/expat/lib")
  cme_export_variable(EXPAT EXPAT_INCLUDE_DIRS "${source}/expat/lib")
endfunction()
