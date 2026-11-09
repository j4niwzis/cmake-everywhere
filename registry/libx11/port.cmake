# Xlib, from X.org's release tarball: an
# autotools build, configured and installed into a prefix of its own.
cme_declare_port(
  NAME libx11
  PROVIDES X11 libX11 x11
  VERSION 1.8.10
  URL "https://xorg.freedesktop.org/archive/individual/lib/libX11-1.8.10.tar.xz"
  URL_HASH "SHA256=2b3b3dad9347db41dca56beb7db5878f283bde1142f04d9f8e478af435dfdc53"
  LICENSE MIT
  CONFIGURE YES
  DEPENDS xorgproto xtrans libxcb libxau
  INSTALLED_TARGETS "lib/libX11.a=X11::X11"
  SYSTEM_PKGCONFIG "x11:X11::X11"
  TARGETS X11::X11
  CHECK_HEADER X11/Xlib.h
  CONFIGURE_ARGS
    "--disable-shared"
    "--enable-static"
    "--with-pic"
    "--disable-specs"
    "--without-xmlto"
    "--without-fop"
    "--without-xsltproc"
  CONFIGURE_CROSS "--host=@TRIPLE@"
)

# A static library, linked with what it calls: the libraries below it.
function(cme_adapt_libx11 source binary)
  if(TARGET X11::X11)
    set_property(TARGET X11::X11 APPEND PROPERTY INTERFACE_LINK_LIBRARIES X11::xcb X11::xorgproto)
  endif()
endfunction()
