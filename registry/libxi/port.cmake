# The X Input extension's client library, from X.org's release tarball: an
# autotools build, configured and installed into a prefix of its own.
cme_declare_port(
  NAME libxi
  PROVIDES Xi libXi xi
  VERSION 1.8.2
  URL "https://xorg.freedesktop.org/archive/individual/lib/libXi-1.8.2.tar.xz"
  URL_HASH "SHA256=d0e0555e53d6e2114eabfa44226ba162d2708501a25e18d99cfb35c094c6c104"
  LICENSE MIT
  CONFIGURE YES
  DEPENDS libxext libxfixes libx11
  INSTALLED_TARGETS "lib/libXi.a=X11::Xi"
  SYSTEM_PKGCONFIG "xi:X11::Xi"
  TARGETS X11::Xi
  CHECK_HEADER X11/Xlib.h X11/extensions/XInput2.h
  CONFIGURE_ARGS
    "--disable-shared"
    "--enable-static"
    "--with-pic"
    "--disable-specs"
    "--without-xmlto"
    "--without-fop"
    "--without-asciidoc"
  CONFIGURE_CROSS "--host=@TRIPLE@"
)

# A static library, linked with what it calls: the libraries below it.
function(cme_adapt_libxi source binary)
  if(TARGET X11::Xi)
    set_property(TARGET X11::Xi APPEND PROPERTY INTERFACE_LINK_LIBRARIES X11::Xext X11::Xfixes X11::X11)
  endif()
endfunction()
