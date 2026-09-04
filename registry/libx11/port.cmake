# The X client library. Everything on the X side of a window goes through
# it: GLFW opens the display with it, and its own connection underneath is
# the xcb one this build already carries.
cme_declare_port(
  NAME libx11
  PROVIDES libX11 libx11
  VERSION 1.8.12
  # The release archive, which carries the configure script: this is
  # autotools, and a checkout has only what generates one.
  URL "https://www.x.org/releases/individual/lib/libX11-1.8.12.tar.xz"
  URL_HASH "SHA256=fa026f9bb0124f4d6c808f9aef4057aad65e7b35d8ff43951cef0abe06bb9a9a"
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
