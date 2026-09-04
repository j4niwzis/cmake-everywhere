# The older way of asking where the monitors are, which GLFW falls back to.
cme_declare_port(
  NAME libxinerama
  PROVIDES libXinerama libxinerama
  VERSION 1.1.5
  # The release archive, which carries the configure script: this is
  # autotools, and a checkout has only what generates one.
  URL "https://www.x.org/releases/individual/lib/libXinerama-1.1.5.tar.xz"
  URL_HASH "SHA256=5094d1f0fcc1828cb1696d0d39d9e866ae32520c54d01f618f1a3c1e30c2085c"
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
