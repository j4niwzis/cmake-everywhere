# Missing upstream: dependencies resolved rather than assumed.
cme_declare_port(
  NAME flac
  PROVIDES FLAC flac
  VERSION 1.4.3
  GITHUB_REPOSITORY xiph/flac
  GIT_TAG 1.4.3
  OPTIONS
    "WITH_OGG OFF"
    "BUILD_PROGRAMS OFF"
    "BUILD_EXAMPLES OFF"
    "BUILD_DOCS OFF"
    "BUILD_TESTING OFF"
    "BUILD_CXXLIBS OFF"
    "INSTALL_MANPAGES OFF"
    "WITH_FORTIFY_SOURCE OFF"
  SYSTEM_PKGCONFIG "flac:FLAC::FLAC"
  GIT_TAG_TEMPLATE "@VERSION@"
)

# libFLAC can be built with or without Ogg, and which one a system copy is
# cannot be read anywhere -- but it can be looked for: the Ogg entry points
# are only compiled when it was.
cme_port_feature(flac ogg
  SUMMARY "FLAC inside an Ogg container"
  DEPENDS "ogg>=1.3"
  OPTIONS "WITH_OGG ON"
  SYSTEM_SYMBOLS "FLAC__stream_encoder_init_ogg_stream:FLAC/stream_encoder.h")

function(cme_adapt_flac source binary)
  cme_alias(FLAC::FLAC FLAC)
  cme_export_variable(FLAC FLAC_FOUND TRUE)
  cme_export_variable(FLAC FLAC_LIBRARY FLAC::FLAC)
  cme_export_variable(FLAC FLAC_LIBRARIES FLAC::FLAC)
  cme_export_variable(FLAC FLAC_INCLUDE_DIR "${source}/include")
  cme_export_variable(FLAC FLAC_INCLUDE_DIRS "${source}/include")
  cme_export_variable(FLAC FLAC_VERSION 1.4.3)
endfunction()
