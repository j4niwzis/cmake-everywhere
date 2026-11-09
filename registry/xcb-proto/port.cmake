# The X protocol described in XML, and the Python that turns the description
# into C (xcbgen): what libxcb is generated from. Installed, nothing built;
# libxcb's configure finds it by its pkg-config file in the prefix.
cme_declare_port(
  NAME xcb-proto
  PROVIDES xcb-proto
  VERSION 1.17.0
  URL "https://xorg.freedesktop.org/archive/individual/proto/xcb-proto-1.17.0.tar.xz"
  URL_HASH "SHA256=2c1bacd2110f4799f74de6ebb714b94cf6f80fb112316b1219480fd22562148c"
  LICENSE MIT
  CONFIGURE YES
  TARGETS X11::xcb-proto
  CONFIGURE_CROSS "--host=@TRIPLE@"
)
function(cme_adapt_xcb-proto source binary)
  if(NOT TARGET X11::xcb-proto)
    add_library(X11::xcb-proto INTERFACE IMPORTED GLOBAL)
  endif()
endfunction()
