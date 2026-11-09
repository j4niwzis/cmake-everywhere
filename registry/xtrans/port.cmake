# X's transport layer, as sources a library compiles into itself (Xlib):
# headers and C files installed, nothing built.
cme_declare_port(
  NAME xtrans
  PROVIDES xtrans
  VERSION 1.5.2
  URL "https://xorg.freedesktop.org/archive/individual/lib/xtrans-1.5.2.tar.xz"
  URL_HASH "SHA256=5c5cbfe34764a9131d048f03c31c19e57fb4c682d67713eab6a65541b4dff86c"
  LICENSE MIT
  # Sources and headers that X libraries include, under X11/Xtrans: the
  # tree itself, seen under that name.
  CONFIGURE YES
  IMPORT make
  DEPENDS xorgproto
  SYSTEM_PKGCONFIG "xtrans:X11::xtrans"
  TARGETS X11::xtrans
  CHECK_HEADER X11/Xtrans/Xtrans.h
  CONFIGURE_CROSS "--host=@TRIPLE@"
)
# Headers only: a target that carries the installed include directory.
function(cme_adapt_xtrans source binary)
  if(NOT TARGET X11::xtrans)
    set(staged "${CMAKE_BINARY_DIR}/_cme/xtrans-include")
    file(MAKE_DIRECTORY "${staged}/X11")
    if(NOT EXISTS "${staged}/X11/Xtrans")
      file(CREATE_LINK "${source}" "${staged}/X11/Xtrans" SYMBOLIC)
    endif()
    add_library(X11::xtrans INTERFACE IMPORTED GLOBAL)
    set_property(TARGET X11::xtrans PROPERTY INTERFACE_INCLUDE_DIRECTORIES "${staged}")
    set_property(TARGET X11::xtrans PROPERTY INTERFACE_LINK_LIBRARIES X11::xorgproto)
  endif()
endfunction()
