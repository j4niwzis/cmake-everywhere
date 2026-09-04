# Pointer barriers and region objects, which the cursor and input code use.
cme_declare_port(
  NAME libxfixes
  PROVIDES libXfixes libxfixes
  VERSION 6.0.1
  GIT_REPOSITORY https://gitlab.freedesktop.org/xorg/lib/libxfixes.git
  GIT_TAG libXfixes-6.0.1
  GIT_TAG_TEMPLATE "libXfixes-@VERSION@"
  LICENSE MIT
  CONFIGURE YES
  DEPENDS libx11 xorgproto
  INSTALLED_TARGETS "lib/libXfixes.a=X11::xfixes"
  INSTALLED_INCLUDE include
  SYSTEM_PKGCONFIG "xfixes:X11::xfixes"
  LINK_NAMES "Xfixes=X11::xfixes"
  TARGETS X11::xfixes
  CHECK_HEADER X11/extensions/Xfixes.h
  CONFIGURE_ARGS "--disable-shared" "--enable-static" "--with-pic"
  CONFIGURE_CROSS "--host=@TRIPLE@"
)
