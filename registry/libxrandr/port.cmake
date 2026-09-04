# Which monitors there are, how big they are and how fast they refresh --
# which is what a window needs before it can go fullscreen on the right one.
cme_declare_port(
  NAME libxrandr
  PROVIDES libXrandr libxrandr
  VERSION 1.5.4
  # The release archive, which carries the configure script: this is
  # autotools, and a checkout has only what generates one.
  URL "https://www.x.org/releases/individual/lib/libXrandr-1.5.4.tar.xz"
  URL_HASH "SHA256=1ad5b065375f4a85915aa60611cc6407c060492a214d7f9daf214be752c3b4d3"
  LICENSE MIT
  CONFIGURE YES
  DEPENDS libx11 libxext libxrender xorgproto
  INSTALLED_TARGETS "lib/libXrandr.a=X11::xrandr"
  INSTALLED_INCLUDE include
  SYSTEM_PKGCONFIG "xrandr:X11::xrandr"
  LINK_NAMES "Xrandr=X11::xrandr"
  TARGETS X11::xrandr
  CHECK_HEADER X11/extensions/Xrandr.h
  CONFIGURE_ARGS "--disable-shared" "--enable-static" "--with-pic"
  CONFIGURE_CROSS "--host=@TRIPLE@"
)
