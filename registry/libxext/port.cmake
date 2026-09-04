# The extensions that are old enough to have been bundled: shape, sync,
# double buffering. Several of the libraries below link it.
cme_declare_port(
  NAME libxext
  PROVIDES libXext libxext
  VERSION 1.3.6
  GIT_REPOSITORY https://gitlab.freedesktop.org/xorg/lib/libxext.git
  GIT_TAG libXext-1.3.6
  GIT_TAG_TEMPLATE "libXext-@VERSION@"
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
