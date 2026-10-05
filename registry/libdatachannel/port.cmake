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
  # Its install rules behind an option, off here: they export its targets,
  # and its dependencies are this build's own targets, in no export set of
  # its -- CMake refused the install(EXPORT), which it checks whether it
  # runs or not.
  PATCHES "patches/0001-install-rules-behind-an-option.patch"
          # std::transform with no <algorithm>: another header brought it in
          # once, and libc++ no longer does.
          "patches/0002-configuration-includes-algorithm.patch"
  OPTIONS
    "LIBDATACHANNEL_INSTALL OFF"
    # C++17, in a build whose own C++ says import std: none of that for
    # this one's targets, which CMake would require C++20 of.
    "CMAKE_CXX_MODULE_STD OFF"
    "CMAKE_CXX_SCAN_FOR_MODULES OFF"
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
