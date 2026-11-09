# The X Render extension's client library, from X.org's release tarball: an
# autotools build, configured and installed into a prefix of its own.
cme_declare_port(
  NAME libxrender
  PROVIDES Xrender libXrender xrender
  VERSION 0.9.12
  URL "https://xorg.freedesktop.org/archive/individual/lib/libXrender-0.9.12.tar.xz"
  URL_HASH "SHA256=b832128da48b39c8d608224481743403ad1691bf4e554e4be9c174df171d1b97"
  LICENSE MIT
  CONFIGURE YES
  DEPENDS libx11 xorgproto
  INSTALLED_TARGETS "lib/libXrender.a=X11::Xrender"
  SYSTEM_PKGCONFIG "xrender:X11::Xrender"
  TARGETS X11::Xrender
  CHECK_HEADER X11/Xlib.h X11/extensions/Xrender.h
  CONFIGURE_ARGS
    "--disable-shared"
    "--enable-static"
    "--with-pic"
  CONFIGURE_CROSS "--host=@TRIPLE@"
)

# A static library, linked with what it calls: the libraries below it.
function(cme_adapt_libxrender source binary)
  if(TARGET X11::Xrender)
    set_property(TARGET X11::Xrender APPEND PROPERTY INTERFACE_LINK_LIBRARIES X11::X11)
  endif()
endfunction()
