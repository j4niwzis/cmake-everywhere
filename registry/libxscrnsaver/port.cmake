# The X Screen Saver extension's client library, from X.org's release tarball: an
# autotools build, configured and installed into a prefix of its own.
cme_declare_port(
  NAME libxscrnsaver
  PROVIDES Xss libXScrnSaver xscrnsaver
  VERSION 1.2.4
  URL "https://xorg.freedesktop.org/archive/individual/lib/libXScrnSaver-1.2.4.tar.xz"
  URL_HASH "SHA256=75cd2859f38e207a090cac980d76bc71e9da99d48d09703584e00585abc920fe"
  LICENSE MIT
  CONFIGURE YES
  DEPENDS libxext libx11
  INSTALLED_TARGETS "lib/libXss.a=X11::Xss"
  SYSTEM_PKGCONFIG "xscrnsaver:X11::Xss"
  TARGETS X11::Xss
  CHECK_HEADER X11/Xlib.h X11/extensions/scrnsaver.h
  CONFIGURE_ARGS
    "--disable-shared"
    "--enable-static"
    "--with-pic"
  CONFIGURE_CROSS "--host=@TRIPLE@"
)

# A static library, linked with what it calls: the libraries below it.
function(cme_adapt_libxscrnsaver source binary)
  if(TARGET X11::Xss)
    set_property(TARGET X11::Xss APPEND PROPERTY INTERFACE_LINK_LIBRARIES X11::Xext X11::X11)
  endif()
endfunction()
