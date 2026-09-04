# Which monitors there are, how big they are and how fast they refresh --
# which is what a window needs before it can go fullscreen on the right one.
cme_declare_port(
  NAME libxrandr
  PROVIDES libXrandr libxrandr
  VERSION 1.5.4
  GIT_REPOSITORY https://gitlab.freedesktop.org/xorg/lib/libxrandr.git
  GIT_TAG libXrandr-1.5.4
  GIT_TAG_TEMPLATE "libXrandr-@VERSION@"
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
