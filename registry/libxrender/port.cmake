# The render extension, which is what a cursor image is uploaded through.
cme_declare_port(
  NAME libxrender
  PROVIDES libXrender libxrender
  VERSION 0.9.12
  GIT_REPOSITORY https://gitlab.freedesktop.org/xorg/lib/libxrender.git
  GIT_TAG libXrender-0.9.12
  GIT_TAG_TEMPLATE "libXrender-@VERSION@"
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
