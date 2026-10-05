# usrsctp: SCTP in user space -- WebRTC's data channels, which
# libdatachannel needs even where only media is sent. Over DTLS only, as
# WebRTC has it: no IPv4 or IPv6 sockets of its own.
cme_declare_port(
  NAME usrsctp
  PROVIDES Usrsctp usrsctp
  VERSION 0.9.5.0
  GITHUB_REPOSITORY sctplab/usrsctp
  GIT_TAG 0.9.5.0
  OPTIONS
    "sctp_build_shared_lib OFF"
    "sctp_build_programs OFF"
    "sctp_inet OFF"
    "sctp_inet6 OFF"
    "sctp_werror OFF"
    "sctp_debug OFF"
  GIT_TAG_TEMPLATE "@VERSION@"
  LICENSE BSD-3-Clause
  TARGETS Usrsctp::Usrsctp
  CHECK_HEADER usrsctp.h
)

function(cme_adapt_usrsctp source binary)
  cme_alias(Usrsctp::Usrsctp usrsctp)
  cme_export_variable(Usrsctp Usrsctp_FOUND TRUE)
endfunction()
