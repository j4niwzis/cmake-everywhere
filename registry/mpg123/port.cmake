# Missing upstream, in the sense this registry is about: mpg123 is an
# autotools project. It carries a CMake build under ports/cmake, which is
# what is used here -- so the library is built in your graph with your
# compiler and your generator rather than by a configure script in a
# subprocess.
#
# From the release archive rather than from a repository. That CMake build
# reads ../../../../src, so it needs the whole tree, and the released tree is
# the one upstream tests it against.
cme_declare_port(
  NAME mpg123
  PROVIDES mpg123 MPG123 Mpg123
  VERSION 1.32.10
  URL "https://www.mpg123.de/download/mpg123-1.32.10.tar.bz2"
  URL_HASH "SHA512=4df3e76cafe642b1df8befaff3d3530150c13446ca7f07b8d527af5b6522e4d2dedd025a3f095f23a51e2318d17e1395de6e55c70e3a90f80017ea0955fe8c1f"
  SOURCE_SUBDIR ports/cmake
  LICENSE LGPL-2.1-only
  SYSTEM_PKGCONFIG "libmpg123:MPG123::libmpg123"
  LINK_NAMES "mpg123=MPG123::libmpg123"
  TARGETS MPG123::libmpg123
  CHECK_HEADER mpg123.h
  # The decoder and nothing else. libout123 is an output layer, the programs
  # are programs, and neither is what anything links.
  # Whether the machine has a floating point unit is a question about the
  # target, and mpg123 asks CMake about the host. Every machine this builds
  # for has one: aarch64 and x86-64 always, and armv7 on Android requires
  # VFP. The patch beside this port makes the answer given here be kept.
  PATCHES "patches/0001-a-floating-point-unit-is-the-target-s.patch"
  OPTIONS
    "HAVE_FPU ON"
    "BUILD_LIBOUT123 OFF"
    "BUILD_PROGRAMS OFF"
    "BUILD_TESTING OFF"
    "USE_MODULES OFF"
)

function(cme_adapt_mpg123 source binary)
  cme_alias(MPG123::libmpg123 libmpg123)
  # Upstream's CMake build puts its binary directory on the interface, which
  # is where config.h is written, and mpg123.h and fmt123.h are files in the
  # source tree that it installs from there. In a build that never installs,
  # the header a consumer includes is on nobody's interface until this says
  # where it is.
  target_include_directories(libmpg123 INTERFACE
    "$<BUILD_INTERFACE:${source}/src/include>")
  cme_export_variable(mpg123 MPG123_FOUND TRUE)
  cme_export_variable(mpg123 MPG123_LIBRARY MPG123::libmpg123)
  cme_export_variable(mpg123 MPG123_LIBRARIES MPG123::libmpg123)
  cme_export_variable(mpg123 MPG123_INCLUDE_DIR "${source}/src/include")
  cme_export_variable(mpg123 MPG123_INCLUDE_DIRS "${source}/src/include;${binary}")
endfunction()
