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
  IMPORT make
  DEPENDS libxext libx11
  IMPORT_TARGETS "Xss=X11::Xss"
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
  # Its headers are its tree's (include/X11/extensions), compiled here.
  if(TARGET libxscrnsaver_Xss)
    target_include_directories(libxscrnsaver_Xss INTERFACE "$<BUILD_INTERFACE:${source}/include>")
    target_link_libraries(libxscrnsaver_Xss INTERFACE X11::Xext X11::X11)
  endif()
endfunction()
