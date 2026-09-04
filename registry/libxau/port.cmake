# The authority file an X client reads to prove who it is.
#
# Sixteen kilobytes of library that every X connection needs: libxcb reads
# ~/.Xauthority through it before it says anything to the server.
cme_declare_port(
  NAME libxau
  PROVIDES Xau libXau
  VERSION 1.0.12
  GIT_REPOSITORY https://gitlab.freedesktop.org/xorg/lib/libxau.git
  GIT_TAG libXau-1.0.12
  GIT_TAG_TEMPLATE "libXau-@VERSION@"
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
