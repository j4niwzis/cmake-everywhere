# Pointer barriers and region objects, which the cursor and input code use.
cme_declare_port(
  NAME libxfixes
  PROVIDES libXfixes libxfixes
  VERSION 6.0.1
  # The release archive, which carries the configure script: this is
  # autotools, and a checkout has only what generates one.
  URL "https://www.x.org/releases/individual/lib/libXfixes-6.0.1.tar.xz"
  URL_HASH "SHA256=b695f93cd2499421ab02d22744458e650ccc88c1d4c8130d60200213abc02d58"
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
