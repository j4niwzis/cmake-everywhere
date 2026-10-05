# libSRTP: SRTP, what WebRTC's media is encrypted with -- its keys from the
# DTLS handshake. Its ciphers OpenSSL's, AES-GCM among them.
cme_declare_port(
  NAME libsrtp
  PROVIDES libSRTP srtp2
  VERSION 2.8.1
  GITHUB_REPOSITORY cisco/libsrtp
  GIT_TAG v2.8.1
  DEPENDS openssl
  # Its install rules behind an option, off here: they export srtp2, and
  # its OpenSSL is this build's own target, in no export set of its --
  # CMake refused the install(EXPORT), which it checks whether it runs.
  PATCHES "patches/0001-install-rules-behind-an-option.patch"
  OPTIONS
    "LIBSRTP_INSTALL OFF"
    "ENABLE_OPENSSL ON"
    "LIBSRTP_TEST_APPS OFF"
    "BUILD_TESTING OFF"
    "BUILD_SHARED_LIBS OFF"
    "ENABLE_WARNINGS_AS_ERRORS OFF"
  GIT_TAG_TEMPLATE "v@VERSION@"
  LICENSE BSD-3-Clause
  TARGETS libSRTP::srtp2
  CHECK_HEADER srtp2/srtp.h
)

function(cme_adapt_libsrtp source binary)
  # Installed, its header is srtp2/srtp.h, which is what a consumer writes
  # (libdatachannel among them); from the source tree it is include/srtp.h,
  # with no such prefix, and the install is off here.
  cme_header_prefix(named srtp2 "${source}/include")
  target_include_directories(srtp2 INTERFACE "$<BUILD_INTERFACE:${named}>")
  cme_export_variable(libSRTP libSRTP_FOUND TRUE)
endfunction()
