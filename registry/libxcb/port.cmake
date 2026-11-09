# The X protocol's C binding, generated from xcb-proto's description by Python, from X.org's release tarball: an
# autotools build, configured and installed into a prefix of its own.
cme_declare_port(
  NAME libxcb
  PROVIDES xcb XCB libxcb
  VERSION 1.17.0
  URL "https://xorg.freedesktop.org/archive/individual/lib/libxcb-1.17.0.tar.xz"
  URL_HASH "SHA256=599ebf9996710fea71622e6e184f3a8ad5b43d0e5fa8c4e407123c88a59a6d55"
  LICENSE MIT
  CONFIGURE YES
  DEPENDS xcb-proto libxau xorgproto
  INSTALLED_TARGETS "lib/libxcb.a=X11::xcb"
  SYSTEM_PKGCONFIG "xcb:X11::xcb"
  TARGETS X11::xcb
  CHECK_HEADER xcb/xcb.h
  CONFIGURE_ARGS
    "--disable-shared"
    "--enable-static"
    "--with-pic"
    "--without-doxygen"
    "--disable-devel-docs"
  CONFIGURE_CROSS "--host=@TRIPLE@"
)

# A static library, linked with what it calls: the libraries below it.
function(cme_adapt_libxcb source binary)
  if(TARGET X11::xcb)
    set_property(TARGET X11::xcb APPEND PROPERTY INTERFACE_LINK_LIBRARIES X11::Xau)
  endif()
endfunction()
