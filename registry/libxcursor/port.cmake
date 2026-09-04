# Cursor themes: the images a window sets for resizing and pointing.
cme_declare_port(
  NAME libxcursor
  PROVIDES libXcursor libxcursor
  VERSION 1.2.3
  # The release archive, which carries the configure script: this is
  # autotools, and a checkout has only what generates one.
  URL "https://www.x.org/releases/individual/lib/libXcursor-1.2.3.tar.xz"
  URL_HASH "SHA256=fde9402dd4cfe79da71e2d96bb980afc5e6ff4f8a7d74c159e1966afb2b2c2c0"
  LICENSE MIT
  CONFIGURE YES
  DEPENDS libx11 libxrender libxfixes xorgproto
  INSTALLED_TARGETS "lib/libXcursor.a=X11::xcursor"
  INSTALLED_INCLUDE include
  SYSTEM_PKGCONFIG "xcursor:X11::xcursor"
  LINK_NAMES "Xcursor=X11::xcursor"
  TARGETS X11::xcursor
  CHECK_HEADER X11/Xcursor/Xcursor.h
  CONFIGURE_ARGS "--disable-shared" "--enable-static" "--with-pic"
  CONFIGURE_CROSS "--host=@TRIPLE@"
)
