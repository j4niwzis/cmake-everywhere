# libSRTP: SRTP, what WebRTC's media is encrypted with -- its keys from the
# DTLS handshake. Its ciphers OpenSSL's, AES-GCM among them.
cme_declare_port(
  NAME libsrtp
  PROVIDES libSRTP srtp2
  VERSION 2.8.1
  GITHUB_REPOSITORY cisco/libsrtp
  GIT_TAG v2.8.1
  DEPENDS openssl
  OPTIONS
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
  cme_export_variable(libSRTP libSRTP_FOUND TRUE)
endfunction()
