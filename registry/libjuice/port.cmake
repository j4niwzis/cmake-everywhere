# libjuice: ICE (RFC 8445) -- a call's way through NATs, with STUN and TURN.
cme_declare_port(
  NAME libjuice
  PROVIDES LibJuice juice
  VERSION 1.7.4
  GITHUB_REPOSITORY paullouisageneau/libjuice
  GIT_TAG v1.7.4
  OPTIONS
    "BUILD_SHARED_LIBS OFF"
    "NO_SERVER ON"
    "NO_TESTS ON"
  GIT_TAG_TEMPLATE "v@VERSION@"
  LICENSE MPL-2.0
  TARGETS LibJuice::LibJuice
  CHECK_HEADER juice/juice.h
)

function(cme_adapt_libjuice source binary)
  cme_export_variable(LibJuice LibJuice_FOUND TRUE)
  cme_export_variable(LibJuice LibJuice_VERSION 1.7.4)
endfunction()
