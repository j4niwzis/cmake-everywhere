# libdatachannel: WebRTC without Google's -- ICE (libjuice), DTLS (OpenSSL),
# SRTP (libSRTP), SCTP (usrsctp) and RTP media tracks. Its dependencies are
# ports of their own, not its submodules: each pinned once, and shared.
cme_declare_port(
  NAME libdatachannel
  PROVIDES LibDataChannel datachannel
  VERSION 0.24.6
  GITHUB_REPOSITORY paullouisageneau/libdatachannel
  GIT_TAG v0.24.6
  DEPENDS openssl plog usrsctp libsrtp libjuice
  OPTIONS
    "BUILD_SHARED_LIBS OFF"
    "USE_SYSTEM_PLOG ON"
    "USE_SYSTEM_USRSCTP ON"
    "USE_SYSTEM_SRTP ON"
    "USE_SYSTEM_JUICE ON"
    "NO_WEBSOCKET ON"
    "NO_EXAMPLES ON"
    "NO_TESTS ON"
  GIT_TAG_TEMPLATE "v@VERSION@"
  LICENSE MPL-2.0
  TARGETS LibDataChannel::LibDataChannel
  CHECK_HEADER rtc/rtc.hpp
)

function(cme_adapt_libdatachannel source binary)
  cme_export_variable(LibDataChannel LibDataChannel_FOUND TRUE)
endfunction()
