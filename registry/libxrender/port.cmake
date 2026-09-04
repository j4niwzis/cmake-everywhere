# The render extension, which is what a cursor image is uploaded through.
cme_declare_port(
  NAME libxrender
  PROVIDES libXrender libxrender
  VERSION 0.9.12
  # The release archive, which carries the configure script: this is
  # autotools, and a checkout has only what generates one.
  URL "https://www.x.org/releases/individual/lib/libXrender-0.9.12.tar.xz"
  URL_HASH "SHA256=b832128da48b39c8d608224481743403ad1691bf4e554e4be9c174df171d1b97"
  LICENSE MIT
  CONFIGURE YES
  DEPENDS libx11 xorgproto
  INSTALLED_TARGETS "lib/libXrender.a=X11::xrender"
  INSTALLED_INCLUDE include
  SYSTEM_PKGCONFIG "xrender:X11::xrender"
  LINK_NAMES "Xrender=X11::xrender"
  TARGETS X11::xrender
  CHECK_HEADER X11/extensions/Xrender.h
  CONFIGURE_ARGS "--disable-shared" "--enable-static" "--with-pic"
  CONFIGURE_CROSS "--host=@TRIPLE@"
)
