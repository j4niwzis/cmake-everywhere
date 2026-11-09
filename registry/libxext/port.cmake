# The common X extensions' client library, from X.org's release tarball: an
# autotools build, configured and installed into a prefix of its own.
cme_declare_port(
  NAME libxext
  PROVIDES Xext libXext xext
  VERSION 1.3.6
  URL "https://xorg.freedesktop.org/archive/individual/lib/libXext-1.3.6.tar.xz"
  URL_HASH "SHA256=edb59fa23994e405fdc5b400afdf5820ae6160b94f35e3dc3da4457a16e89753"
  LICENSE MIT
  CONFIGURE YES
  IMPORT make
  DEPENDS libx11 xorgproto
  IMPORT_TARGETS "Xext=X11::Xext"
  SYSTEM_PKGCONFIG "xext:X11::Xext"
  TARGETS X11::Xext
  CHECK_HEADER X11/Xlib.h X11/extensions/Xext.h
  CONFIGURE_ARGS
    "--disable-shared"
    "--enable-static"
    "--with-pic"
    "--disable-specs"
    "--without-xmlto"
    "--without-fop"
  CONFIGURE_CROSS "--host=@TRIPLE@"
)

# A static library, linked with what it calls: the libraries below it.
function(cme_adapt_libxext source binary)
  # Its headers are its tree's (include/X11/extensions), compiled here.
  if(TARGET libxext_Xext)
    target_include_directories(libxext_Xext INTERFACE "$<BUILD_INTERFACE:${source}/include>")
    target_link_libraries(libxext_Xext INTERFACE X11::X11)
  endif()
endfunction()
