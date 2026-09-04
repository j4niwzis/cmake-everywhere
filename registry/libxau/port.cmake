# The authority file an X client reads to prove who it is.
#
# Sixteen kilobytes of library that every X connection needs: libxcb reads
# ~/.Xauthority through it before it says anything to the server.
cme_declare_port(
  NAME libxau
  PROVIDES Xau libXau
  VERSION 1.0.12
  # The release archive, which carries the configure script: this is
  # autotools, and a checkout has only what generates one.
  URL "https://www.x.org/releases/individual/lib/libXau-1.0.12.tar.xz"
  URL_HASH "SHA256=74d0e4dfa3d39ad8939e99bda37f5967aba528211076828464d2777d477fc0fb"
  LICENSE MIT
  CONFIGURE YES
  INSTALLED_TARGETS "lib/libXau.a=Xau::Xau"
  INSTALLED_INCLUDE include
  SYSTEM_PKGCONFIG "xau:Xau::Xau"
  LINK_NAMES "Xau=Xau::Xau"
  TARGETS Xau::Xau
  CHECK_HEADER X11/Xauth.h
  DEPENDS xorgproto
  CONFIGURE_ARGS "--disable-shared" "--enable-static" "--with-pic"
  CONFIGURE_CROSS "--host=@TRIPLE@"
)
