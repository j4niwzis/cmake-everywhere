# The X protocol's C binding, generated from xcb-proto's description by Python, from X.org's release tarball: an
# autotools build, configured and installed into a prefix of its own.
cme_declare_port(
  NAME libxcb
  PROVIDES xcb XCB libxcb
  VERSION 1.17.0
  URL "https://xorg.freedesktop.org/archive/individual/lib/libxcb-1.17.0.tar.xz"
  URL_HASH "SHA256=599ebf9996710fea71622e6e184f3a8ad5b43d0e5fa8c4e407123c88a59a6d55"
  LICENSE MIT
  # Its configure at the configure stage; its sources, half of them written
  # by xcbgen from the protocol's XML, compiled in this graph.
  CONFIGURE YES
  IMPORT make
  IMPORT_TARGETS "xcb=X11::xcb"
  DEPENDS xcb-proto libxau xorgproto
  SYSTEM_PKGCONFIG "xcb:X11::xcb"
  TARGETS X11::xcb
  CHECK_HEADER xcb/xcb.h
  CONFIGURE_ARGS
    "--disable-shared"
    "--enable-static"
    "--with-pic"
    "--without-doxygen"
    "--disable-devel-docs"
  CONFIGURE_CROSS "--host=@TRIPLE@"
)

# A static library, linked with what it calls: the libraries below it.
# Its headers under xcb/, as they are installed: those of its tree, and
# those xcbgen writes into its build directory (made with the library).
function(cme_adapt_libxcb source binary)
  if(TARGET libxcb_xcb)
    set(built "${CMAKE_BINARY_DIR}/_cme/libxcb-build/src")
    set(staged "${CMAKE_BINARY_DIR}/_cme/libxcb-include")
    file(MAKE_DIRECTORY "${staged}/xcb")
    file(GLOB written RELATIVE "${source}/src" "${source}/src/*.xml")
    file(GLOB headers "${source}/src/*.h")
    foreach(header IN LISTS headers)
      get_filename_component(name "${header}" NAME)
      if(NOT EXISTS "${staged}/xcb/${name}")
        file(CREATE_LINK "${header}" "${staged}/xcb/${name}" SYMBOLIC)
      endif()
    endforeach()
    get_property(source_proto GLOBAL PROPERTY CME_SOURCE_DIR_xcb-proto)
    file(GLOB protocols "${source_proto}/src/*.xml")
    foreach(protocol IN LISTS protocols)
      get_filename_component(name "${protocol}" NAME_WE)
      if(NOT EXISTS "${staged}/xcb/${name}.h")
        file(CREATE_LINK "${built}/${name}.h" "${staged}/xcb/${name}.h" SYMBOLIC)
      endif()
    endforeach()
    # And both halves as they are, unstaged: xcb.h includes "xproto.h" and
    # xproto.h includes "xcb.h", each from beside itself -- one in the tree,
    # the other where xcbgen writes it -- and each finds the other on the
    # include path instead (SDL's Vulkan renderer, through xcb.h).
    target_include_directories(libxcb_xcb INTERFACE "$<BUILD_INTERFACE:${staged}>" "$<BUILD_INTERFACE:${built}>"
      "$<BUILD_INTERFACE:${source}/src>")
    target_link_libraries(libxcb_xcb INTERFACE X11::Xau)
  endif()
endfunction()
