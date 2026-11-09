# The X Resize and Rotate extension's client library, from X.org's release tarball: an
# autotools build, configured and installed into a prefix of its own.
cme_declare_port(
  NAME libxrandr
  PROVIDES Xrandr libXrandr xrandr
  VERSION 1.5.4
  URL "https://xorg.freedesktop.org/archive/individual/lib/libXrandr-1.5.4.tar.xz"
  URL_HASH "SHA256=1ad5b065375f4a85915aa60611cc6407c060492a214d7f9daf214be752c3b4d3"
  LICENSE MIT
  CONFIGURE YES
  DEPENDS libxext libxrender libx11
  INSTALLED_TARGETS "lib/libXrandr.a=X11::Xrandr"
  SYSTEM_PKGCONFIG "xrandr:X11::Xrandr"
  TARGETS X11::Xrandr
  CHECK_HEADER X11/extensions/Xrandr.h
  CONFIGURE_ARGS
    "--disable-shared"
    "--enable-static"
    "--with-pic"
  CONFIGURE_CROSS "--host=@TRIPLE@"
)

# A static library, linked with what it calls: the libraries below it.
function(cme_adapt_libxrandr source binary)
  if(TARGET X11::Xrandr)
    set_property(TARGET X11::Xrandr APPEND PROPERTY INTERFACE_LINK_LIBRARIES X11::Xext X11::Xrender X11::X11)
  endif()
endfunction()
