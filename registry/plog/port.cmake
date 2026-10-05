# plog: a logging library of headers. libdatachannel logs through it.
cme_declare_port(
  NAME plog
  PROVIDES plog
  VERSION 1.1.11
  GITHUB_REPOSITORY SergiusTheBest/plog
  GIT_TAG 1.1.11
  OPTIONS
    "PLOG_BUILD_SAMPLES OFF"
    "PLOG_BUILD_TESTS OFF"
    "PLOG_INSTALL OFF"
  GIT_TAG_TEMPLATE "@VERSION@"
  LICENSE MIT
  TARGETS plog::plog
  CHECK_HEADER plog/Log.h
)
