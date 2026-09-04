# The display manager's handshake, which libxcb links whether or not a
# display manager is involved: the symbols are referenced by its
# authorisation path.
cme_declare_port(
  NAME libxdmcp
  PROVIDES Xdmcp libXdmcp
  VERSION 1.1.5
  GIT_REPOSITORY https://gitlab.freedesktop.org/xorg/lib/libxdmcp.git
  GIT_TAG libXdmcp-1.1.5
  GIT_TAG_TEMPLATE "libXdmcp-@VERSION@"
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
