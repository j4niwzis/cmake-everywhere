# Missing upstream: dependencies resolved rather than assumed.
cme_declare_port(
  NAME flac
  PROVIDES FLAC flac
  VERSION 1.4.3
  GITHUB_REPOSITORY xiph/flac
  GIT_TAG 1.4.3
  DEPENDS ogg
  OPTIONS
    "BUILD_PROGRAMS OFF"
    "BUILD_EXAMPLES OFF"
    "BUILD_DOCS OFF"
    "BUILD_TESTING OFF"
    "BUILD_CXXLIBS OFF"
    "INSTALL_MANPAGES OFF"
    "WITH_FORTIFY_SOURCE OFF"
  SYSTEM_PKGCONFIG "flac:FLAC::FLAC"
)

function(cme_adapt_flac source binary)
  cme_alias(FLAC::FLAC FLAC)
  cme_export_variable(FLAC FLAC_FOUND TRUE)
  cme_export_variable(FLAC FLAC_LIBRARY FLAC::FLAC)
  cme_export_variable(FLAC FLAC_LIBRARIES FLAC::FLAC)
  cme_export_variable(FLAC FLAC_INCLUDE_DIR "${source}/include")
  cme_export_variable(FLAC FLAC_INCLUDE_DIRS "${source}/include")
  cme_export_variable(FLAC FLAC_VERSION 1.4.3)
endfunction()
