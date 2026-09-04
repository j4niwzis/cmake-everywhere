# Cursor themes: the images a window sets for resizing and pointing.
cme_declare_port(
  NAME libxcursor
  PROVIDES libXcursor libxcursor
  VERSION 1.2.3
  GIT_REPOSITORY https://gitlab.freedesktop.org/xorg/lib/libxcursor.git
  GIT_TAG libXcursor-1.2.3
  GIT_TAG_TEMPLATE "libXcursor-@VERSION@"
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
