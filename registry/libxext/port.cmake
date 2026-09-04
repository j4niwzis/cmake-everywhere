# The extensions that are old enough to have been bundled: shape, sync,
# double buffering. Several of the libraries below link it.
cme_declare_port(
  NAME libxext
  PROVIDES libXext libxext
  VERSION 1.3.6
  # The release archive, which carries the configure script: this is
  # autotools, and a checkout has only what generates one.
  URL "https://www.x.org/releases/individual/lib/libXext-1.3.6.tar.xz"
  URL_HASH "SHA256=edb59fa23994e405fdc5b400afdf5820ae6160b94f35e3dc3da4457a16e89753"
  LICENSE MIT
  CONFIGURE YES
  DEPENDS libx11 xorgproto
  INSTALLED_TARGETS "lib/libXext.a=X11::xext"
  INSTALLED_INCLUDE include
  SYSTEM_PKGCONFIG "xext:X11::xext"
  LINK_NAMES "Xext=X11::xext"
  TARGETS X11::xext
  CHECK_HEADER X11/extensions/Xext.h
  CONFIGURE_ARGS "--disable-shared" "--enable-static" "--with-pic"
  CONFIGURE_CROSS "--host=@TRIPLE@"
)
