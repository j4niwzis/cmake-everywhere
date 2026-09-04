# Input version two: raw pointer motion, which is what a game reads when
# the cursor is captured.
cme_declare_port(
  NAME libxi
  PROVIDES libXi libxi
  VERSION 1.8.2
  GIT_REPOSITORY https://gitlab.freedesktop.org/xorg/lib/libxi.git
  GIT_TAG libXi-1.8.2
  GIT_TAG_TEMPLATE "libXi-@VERSION@"
  LICENSE MIT
  CONFIGURE YES
  DEPENDS libx11 libxext libxfixes xorgproto
  INSTALLED_TARGETS "lib/libXi.a=X11::xi"
  INSTALLED_INCLUDE include
  SYSTEM_PKGCONFIG "xi:X11::xi"
  LINK_NAMES "Xi=X11::xi"
  TARGETS X11::xi
  CHECK_HEADER X11/extensions/XInput2.h
  CONFIGURE_ARGS "--disable-shared" "--enable-static" "--with-pic"
  CONFIGURE_CROSS "--host=@TRIPLE@"
)
