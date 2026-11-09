# Missing upstream: any build but its own. libffi is autotools: its
# configure runs while this build is configured (it writes fficonfig.h and
# ffi.h), and then its make is asked what it would do rather than told to
# do it -- every source compiled in this graph, by this build's compiler,
# through libtool's command lines read as the compiles they wrap.
#
# It is here because wayland is built against it, and because a machine that
# has no Wayland has no libffi either as often as not.
cme_declare_port(
  NAME libffi
  PROVIDES libffi ffi FFI
  VERSION 3.4.6
  # The release archive, which carries the configure script: this is
  # autotools, and a checkout has only what generates one.
  URL "https://github.com/libffi/libffi/releases/download/v3.4.6/libffi-3.4.6.tar.gz"
  URL_HASH "SHA256=b0dea9df23c863a7a50e825440f3ebffabd65df1497108e5d437747843895a4e"
  LICENSE MIT
  CONFIGURE YES
  IMPORT make
  IMPORT_TARGETS "ffi=FFI::ffi"
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

function(cme_adapt_libffi source binary)
  # ffi.h and ffitarget.h, which its configure writes into its build
  # directory, and the headers of its own tree, for whoever links it.
  set(built "${CMAKE_BINARY_DIR}/_cme/libffi-build")
  if(TARGET libffi_ffi)
    target_include_directories(libffi_ffi INTERFACE
      "$<BUILD_INTERFACE:${built}/include>" "$<BUILD_INTERFACE:${source}/include>")
  endif()
  cme_export_variable(libffi LIBFFI_INCLUDE_DIRS "${built}/include")
endfunction()
