# Missing upstream: nothing. ctre is a header, and it ships CMake that exports
# ctre::ctre as an interface target and installs a ctre.pc.
#
# The options turn off what it builds when it is the top-level project: its
# tests, and the Debian and RPM packages it would otherwise offer to make. It
# guards those with cmake_dependent_option, so a build that includes it as a
# subproject already has them off -- they are said here so that the port does
# not depend on that guard staying.
#
# CTRE_MODULE is left off. On, it builds the header as a C++ module, which is
# a different target and a different question; what this port provides is the
# header.
cme_declare_port(
  NAME ctre
  PROVIDES ctre
  VERSION 3.11.0
  GITHUB_REPOSITORY hanickadot/compile-time-regular-expressions
  GIT_TAG v3.11.0
  GIT_TAG_TEMPLATE "v@VERSION@"
  OPTIONS
    "CTRE_BUILD_TESTS OFF"
    "CTRE_BUILD_PACKAGE OFF"
    "CTRE_BUILD_PACKAGE_DEB OFF"
    "CTRE_BUILD_PACKAGE_RPM OFF"
  SYSTEM_PKGCONFIG "ctre:ctre::ctre"
  LICENSE Apache-2.0
  LINK_NAMES
    "ctre=ctre::ctre"
  TARGETS ctre::ctre
  CHECK_HEADER ctre.hpp
)
