# Missing upstream: any build but its own. libffi is autotools, and there is
# nothing in it to ask what it would build -- so it is built the way it
# builds, into a prefix, and the archive that comes out is a target here.
#
# It is here because wayland is built against it, and because a machine that
# has no Wayland has no libffi either as often as not.
cme_declare_port(
  NAME libffi
  PROVIDES libffi ffi FFI
  VERSION 3.4.6
  GITHUB_REPOSITORY libffi/libffi
  GIT_TAG v3.4.6
  GIT_TAG_TEMPLATE "v@VERSION@"
  LICENSE MIT
  CONFIGURE YES
  INSTALLED_TARGETS "lib/libffi.a=FFI::ffi"
  # Autotools puts the two generated headers under the library directory,
  # which is where ffi.h and ffitarget.h are.
  INSTALLED_INCLUDE include lib/libffi-3.4.6/include
  SYSTEM_PKGCONFIG "libffi:FFI::ffi"
  LINK_NAMES "ffi=FFI::ffi"
  TARGETS FFI::ffi
  CHECK_HEADER ffi.h
  CONFIGURE_ARGS
    "--disable-shared"
    "--enable-static"
    "--disable-docs"
    "--with-pic"
  # A configure script has to be told which machine it builds for, and each
  # one is told differently. This is the autotools spelling.
  CONFIGURE_CROSS "--host=@TRIPLE@"
)
