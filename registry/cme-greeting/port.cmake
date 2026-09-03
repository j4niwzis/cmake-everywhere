# The Rust library this registry tests its cargo support with.
#
# It lives here rather than in a repository of its own because what it is for
# is the mechanism, not the code: a crate that builds a static library with a
# C entry point, so that a C++ build can link it and check what it says.
cme_declare_port(
  NAME cme-greeting
  PROVIDES cme-greeting cme_greeting
  VERSION 0.1.0
  IMPORT cargo
  SOURCE_DIR "${CMAKE_CURRENT_LIST_DIR}/../../test/cargo/greeting"
  LICENSE BSD-3-Clause
  TARGETS cme::greeting
)
