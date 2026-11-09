# The X authorization protocol's library, from X.org's release tarball: an
# autotools build, configured and installed into a prefix of its own.
cme_declare_port(
  NAME libxau
  PROVIDES Xau libXau xau
  VERSION 1.0.12
  URL "https://xorg.freedesktop.org/archive/individual/lib/libXau-1.0.12.tar.xz"
  URL_HASH "SHA256=74d0e4dfa3d39ad8939e99bda37f5967aba528211076828464d2777d477fc0fb"
  LICENSE MIT
  CONFIGURE YES
  IMPORT make
  IMPORT_TARGETS "Xau=X11::Xau"
  DEPENDS xorgproto
  SYSTEM_PKGCONFIG "xau:X11::Xau"
  TARGETS X11::Xau
  CHECK_HEADER X11/Xauth.h
  CONFIGURE_ARGS
    "--disable-shared"
    "--enable-static"
    "--with-pic"
  CONFIGURE_CROSS "--host=@TRIPLE@"
)

# A static library, linked with what it calls: the libraries below it.
function(cme_adapt_libxau source binary)
  if(TARGET libxau_Xau)
    target_include_directories(libxau_Xau INTERFACE "$<BUILD_INTERFACE:${source}/include>")
    target_link_libraries(libxau_Xau INTERFACE X11::xorgproto)
  endif()
endfunction()
