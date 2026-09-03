# Almost nothing missing upstream: libogg exports Ogg::ogg properly. This port
# exists for the legacy variables that older revisions of FLAC and libsndfile
# read, and should be deletable.
cme_declare_port(
  NAME ogg
  PROVIDES Ogg ogg OGG
  VERSION 1.3.5
  GITHUB_REPOSITORY xiph/ogg
  GIT_TAG v1.3.5
  OPTIONS
    "INSTALL_DOCS OFF"
    "BUILD_TESTING OFF"
  SYSTEM_PKGCONFIG "ogg:Ogg::ogg"
  GIT_TAG_TEMPLATE "v@VERSION@"
)

# The variables are exported because FLAC and libsndfile look for OGG_LIBRARY
# and OGG_INCLUDE_DIR in some of their revisions.
function(cme_adapt_ogg source binary)
  # libogg names Ogg::ogg itself, so this does nothing there. It is here for
  # the revisions that only name it in the config file they install, which a
  # build tree does not have.
  cme_alias(Ogg::ogg ogg)
  cme_export_variable(Ogg OGG_FOUND TRUE)
  cme_export_variable(Ogg OGG_LIBRARY Ogg::ogg)
  cme_export_variable(Ogg OGG_LIBRARIES Ogg::ogg)
  cme_export_variable(Ogg OGG_INCLUDE_DIR "${source}/include;${binary}/include")
  cme_export_variable(Ogg OGG_INCLUDE_DIRS "${source}/include;${binary}/include")
  cme_export_variable(Ogg OGG_VERSION 1.3.5)
endfunction()
