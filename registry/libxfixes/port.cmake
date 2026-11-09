# The X Fixes extension's client library, from X.org's release tarball: an
# autotools build, configured and installed into a prefix of its own.
cme_declare_port(
  NAME libxfixes
  PROVIDES Xfixes libXfixes xfixes
  VERSION 6.0.1
  URL "https://xorg.freedesktop.org/archive/individual/lib/libXfixes-6.0.1.tar.xz"
  URL_HASH "SHA256=b695f93cd2499421ab02d22744458e650ccc88c1d4c8130d60200213abc02d58"
  LICENSE MIT
  CONFIGURE YES
  IMPORT make
  DEPENDS libx11 xorgproto
  IMPORT_TARGETS "Xfixes=X11::Xfixes"
  SYSTEM_PKGCONFIG "xfixes:X11::Xfixes"
  TARGETS X11::Xfixes
  CHECK_HEADER X11/Xlib.h X11/extensions/Xfixes.h
  CONFIGURE_ARGS
    "--disable-shared"
    "--enable-static"
    "--with-pic"
  CONFIGURE_CROSS "--host=@TRIPLE@"
)

# A static library, linked with what it calls: the libraries below it.
function(cme_adapt_libxfixes source binary)
  # Its headers are its tree's (include/X11/extensions), compiled here.
  if(TARGET libxfixes_Xfixes)
    target_include_directories(libxfixes_Xfixes INTERFACE "$<BUILD_INTERFACE:${source}/include>")
    target_link_libraries(libxfixes_Xfixes INTERFACE X11::X11)
  endif()
endfunction()
