# Nothing missing upstream either: opus exports Opus::opus. What is left here
# is the same list -- where to find it, what it answers to, what it is under
# -- which is the shape a port keeps once it has nothing to fix.
cme_declare_port(
  NAME opus
  PROVIDES Opus opus OPUS
  VERSION 1.5.2
  GITHUB_REPOSITORY xiph/opus
  GIT_TAG v1.5.2
  OPTIONS
    "OPUS_BUILD_PROGRAMS OFF"
    "OPUS_BUILD_TESTING OFF"
    "OPUS_BUILD_SHARED_LIBRARY OFF"
  SYSTEM_PKGCONFIG "opus:Opus::opus"
  GIT_TAG_TEMPLATE "v@VERSION@"
  LICENSE BSD-3-Clause
  # What this library answers to when something asks the linker for it by
  # name. A bare -l finds whatever is installed; a target is an archive
  # with a path.
  LINK_NAMES
    "opus=Opus::opus"
)

function(cme_adapt_opus source binary)
  cme_alias(Opus::opus opus)
  cme_export_variable(Opus OPUS_FOUND TRUE)
  cme_export_variable(Opus OPUS_LIBRARY Opus::opus)
  cme_export_variable(Opus OPUS_LIBRARIES Opus::opus)
  cme_export_variable(Opus OPUS_INCLUDE_DIR "${source}/include")
  cme_export_variable(Opus OPUS_INCLUDE_DIRS "${source}/include")
  cme_export_variable(Opus OPUS_VERSION 1.5.2)
endfunction()
