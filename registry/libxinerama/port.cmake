# The older way of asking where the monitors are, which GLFW falls back to.
cme_declare_port(
  NAME libxinerama
  PROVIDES libXinerama libxinerama
  VERSION 1.1.5
  GIT_REPOSITORY https://gitlab.freedesktop.org/xorg/lib/libxinerama.git
  GIT_TAG libXinerama-1.1.5
  GIT_TAG_TEMPLATE "libXinerama-@VERSION@"
  LICENSE MIT
  CONFIGURE YES
  DEPENDS libx11 libxext xorgproto
  INSTALLED_TARGETS "lib/libXinerama.a=X11::xinerama"
  INSTALLED_INCLUDE include
  SYSTEM_PKGCONFIG "xinerama:X11::xinerama"
  LINK_NAMES "Xinerama=X11::xinerama"
  TARGETS X11::xinerama
  CHECK_HEADER X11/extensions/Xinerama.h
  CONFIGURE_ARGS "--disable-shared" "--enable-static" "--with-pic"
  CONFIGURE_CROSS "--host=@TRIPLE@"
)
