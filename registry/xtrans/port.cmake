# The transport layer libX11 is compiled from: headers and macros for
# sockets, and nothing that is compiled on its own.
cme_declare_port(
  NAME xtrans
  PROVIDES xtrans
  VERSION 1.5.2
  # The release archive, which carries the configure script: this is
  # autotools, and a checkout has only what generates one.
  URL "https://www.x.org/releases/individual/lib/xtrans-1.5.2.tar.xz"
  URL_HASH "SHA256=5c5cbfe34764a9131d048f03c31c19e57fb4c682d67713eab6a65541b4dff86c"
  LICENSE MIT
  CONFIGURE YES
  INSTALLED_TARGETS ""
  INSTALLED_INCLUDE include
  SYSTEM_PKGCONFIG "xtrans"
  CONFIGURE_ARGS "--disable-shared" "--enable-static" "--with-pic"
  CONFIGURE_CROSS "--host=@TRIPLE@"
)
