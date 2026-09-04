# The display manager's handshake, which libxcb links whether or not a
# display manager is involved: the symbols are referenced by its
# authorisation path.
cme_declare_port(
  NAME libxdmcp
  PROVIDES Xdmcp libXdmcp
  VERSION 1.1.5
  # The release archive, which carries the configure script: this is
  # autotools, and a checkout has only what generates one.
  URL "https://www.x.org/releases/individual/lib/libXdmcp-1.1.5.tar.xz"
  URL_HASH "SHA256=d8a5222828c3adab70adf69a5583f1d32eb5ece04304f7f8392b6a353aa2228c"
  LICENSE MIT
  CONFIGURE YES
  INSTALLED_TARGETS "lib/libXdmcp.a=Xdmcp::Xdmcp"
  INSTALLED_INCLUDE include
  SYSTEM_PKGCONFIG "xdmcp:Xdmcp::Xdmcp"
  LINK_NAMES "Xdmcp=Xdmcp::Xdmcp"
  TARGETS Xdmcp::Xdmcp
  CHECK_HEADER X11/Xdmcp.h
  DEPENDS xorgproto
  CONFIGURE_ARGS "--disable-shared" "--enable-static" "--with-pic"
  CONFIGURE_CROSS "--host=@TRIPLE@"
)
