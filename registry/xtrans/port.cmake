# The transport layer libX11 is compiled from: headers and macros for
# sockets, and nothing that is compiled on its own.
cme_declare_port(
  NAME xtrans
  PROVIDES xtrans
  VERSION 1.5.2
  GIT_REPOSITORY https://gitlab.freedesktop.org/xorg/lib/libxtrans.git
  GIT_TAG xtrans-1.5.2
  GIT_TAG_TEMPLATE "xtrans-@VERSION@"
  LICENSE MIT
  CONFIGURE YES
  INSTALLED_TARGETS ""
  INSTALLED_INCLUDE include
  SYSTEM_PKGCONFIG "xtrans"
  CONFIGURE_ARGS "--disable-shared" "--enable-static" "--with-pic"
  CONFIGURE_CROSS "--host=@TRIPLE@"
)
