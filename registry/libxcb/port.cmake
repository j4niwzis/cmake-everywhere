# The X connection itself: the socket, the request queue, and one function
# per protocol request.
#
# Almost none of it exists in its own tree. The requests are generated from
# the XML in xcb-proto by the Python beside it, which is why that is a
# dependency of this build and of nothing else.
#
# This is what an X11 window is made of here, and what Mesa talks DRI3 and
# Present over. A static program needs it as an archive: the alternative is
# the machine's libxcb.so, which is exactly what such a program cannot open.
cme_declare_port(
  NAME libxcb
  PROVIDES XCB libxcb xcb
  VERSION 1.17.0
  GIT_REPOSITORY https://gitlab.freedesktop.org/xorg/lib/libxcb.git
  GIT_TAG libxcb-1.17.0
  GIT_TAG_TEMPLATE "libxcb-@VERSION@"
  LICENSE MIT
  CONFIGURE YES
  DEPENDS xcb-proto libxau libxdmcp xorgproto
  # One archive per extension, which is how libxcb installs: a consumer
  # links the core library and the extensions it speaks. Mesa's X11 platform
  # wants dri3, present, sync, shm, xfixes and randr; a window wants xkb for
  # the keyboard and xinput for everything else.
  INSTALLED_TARGETS
    "lib/libxcb.a=XCB::xcb"
    "lib/libxcb-dri3.a=XCB::dri3"
    "lib/libxcb-present.a=XCB::present"
    "lib/libxcb-sync.a=XCB::sync"
    "lib/libxcb-shm.a=XCB::shm"
    "lib/libxcb-xfixes.a=XCB::xfixes"
    "lib/libxcb-randr.a=XCB::randr"
    "lib/libxcb-render.a=XCB::render"
    "lib/libxcb-shape.a=XCB::shape"
    "lib/libxcb-xkb.a=XCB::xkb"
    "lib/libxcb-xinput.a=XCB::xinput"
    "lib/libxcb-dri2.a=XCB::dri2"
    "lib/libxcb-glx.a=XCB::glx"
  INSTALLED_INCLUDE include
  SYSTEM_PKGCONFIG
    "xcb:XCB::xcb"
    "xcb-dri3:XCB::dri3"
    "xcb-present:XCB::present"
    "xcb-sync:XCB::sync"
    "xcb-shm:XCB::shm"
    "xcb-xfixes:XCB::xfixes"
    "xcb-randr:XCB::randr"
    "xcb-render:XCB::render"
    "xcb-shape:XCB::shape"
    "xcb-xkb:XCB::xkb"
    "xcb-xinput:XCB::xinput"
  LINK_NAMES
    "xcb=XCB::xcb"
    "xcb-dri3=XCB::dri3"
    "xcb-present=XCB::present"
    "xcb-sync=XCB::sync"
    "xcb-shm=XCB::shm"
    "xcb-xfixes=XCB::xfixes"
    "xcb-randr=XCB::randr"
    "xcb-render=XCB::render"
    "xcb-shape=XCB::shape"
    "xcb-xkb=XCB::xkb"
    "xcb-xinput=XCB::xinput"
  TARGETS XCB::xcb
  CHECK_HEADER xcb/xcb.h
  CONFIGURE_ARGS
    "--disable-shared"
    "--enable-static"
    "--with-pic"
    "--enable-xkb"
    "--enable-xinput"
    "--enable-dri3"
    "--enable-present"
    # The documentation needs doxygen, and the sources are generated, so
    # there is nothing to document that anybody reads.
    "--disable-devel-docs"
  CONFIGURE_CROSS "--host=@TRIPLE@"
)
