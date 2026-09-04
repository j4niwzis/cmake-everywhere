# The X client library. Everything on the X side of a window goes through
# it: GLFW opens the display with it, and its own connection underneath is
# the xcb one this build already carries.
cme_declare_port(
  NAME libx11
  PROVIDES libX11 libx11
  VERSION 1.8.12
  GIT_REPOSITORY https://gitlab.freedesktop.org/xorg/lib/libx11.git
  GIT_TAG libX11-1.8.12
  GIT_TAG_TEMPLATE "libX11-@VERSION@"
  LICENSE MIT
  CONFIGURE YES
  DEPENDS libxcb xorgproto xtrans
  INSTALLED_TARGETS "lib/libX11.a=X11::x11"
  INSTALLED_INCLUDE include
  SYSTEM_PKGCONFIG "x11:X11::x11"
  LINK_NAMES "X11=X11::x11"
  TARGETS X11::x11
  CHECK_HEADER X11/Xlib.h
  CONFIGURE_ARGS "--disable-shared" "--enable-static" "--with-pic"
  CONFIGURE_CROSS "--host=@TRIPLE@"
)
