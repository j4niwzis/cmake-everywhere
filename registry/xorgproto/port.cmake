# The X protocol's headers -- the core and every extension -- and their pkg-config
# files: nothing to link, everything an X library and its users include.
cme_declare_port(
  NAME xorgproto
  PROVIDES xorgproto xproto
  VERSION 2024.1
  URL "https://xorg.freedesktop.org/archive/individual/proto/xorgproto-2024.1.tar.xz"
  URL_HASH "SHA256=372225fd40815b8423547f5d890c5debc72e88b91088fbfb13158c20495ccb59"
  LICENSE MIT
  # Its configure runs at the configure stage (it writes Xfuncproto.h and
  # Xpoll.h), and there is nothing to compile: the headers are its tree's
  # and its build directory's, and every protocol's .pc is written by
  # cmake-everywhere, one name each, for the configure scripts that ask.
  CONFIGURE YES
  IMPORT make
  # libX11's configure finds keysymdef.h by xproto's includedir.
  PKGCONFIG_VARIABLES "includedir=@SOURCE@/include"
  PKGCONFIG_NAMES "applewmproto" "bigreqsproto" "compositeproto" "damageproto" "dmxproto" "dpmsproto" "dri2proto" "dri3proto" "fixesproto" "fontsproto" "glproto" "inputproto" "kbproto" "presentproto" "randrproto" "recordproto" "renderproto" "resourceproto" "scrnsaverproto" "videoproto" "xcmiscproto" "xextproto" "xf86bigfontproto" "xf86dgaproto" "xf86driproto" "xf86vidmodeproto" "xineramaproto" "xproto" "xwaylandproto"
  SYSTEM_PKGCONFIG "xproto:X11::xorgproto"
  TARGETS X11::xorgproto
  CHECK_HEADER X11/X.h
  CONFIGURE_CROSS "--host=@TRIPLE@"
)
# Headers only: a target that carries the installed include directory.
function(cme_adapt_xorgproto source binary)
  if(NOT TARGET X11::xorgproto)
    add_library(X11::xorgproto INTERFACE IMPORTED GLOBAL)
    set_property(TARGET X11::xorgproto PROPERTY INTERFACE_INCLUDE_DIRECTORIES
      "${CMAKE_BINARY_DIR}/_cme/xorgproto-build/include" "${source}/include")
  endif()
endfunction()
