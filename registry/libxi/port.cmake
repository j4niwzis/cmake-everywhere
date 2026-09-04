# Input version two: raw pointer motion, which is what a game reads when
# the cursor is captured.
cme_declare_port(
  NAME libxi
  PROVIDES libXi libxi
  VERSION 1.8.2
  # The release archive, which carries the configure script: this is
  # autotools, and a checkout has only what generates one.
  URL "https://www.x.org/releases/individual/lib/libXi-1.8.2.tar.xz"
  URL_HASH "SHA256=d0e0555e53d6e2114eabfa44226ba162d2708501a25e18d99cfb35c094c6c104"
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
