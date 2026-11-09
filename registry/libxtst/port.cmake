# The X Test extension's client library, from X.org's release tarball: an
# autotools build, configured and installed into a prefix of its own.
cme_declare_port(
  NAME libxtst
  PROVIDES Xtst libXtst xtst
  VERSION 1.2.5
  URL "https://xorg.freedesktop.org/archive/individual/lib/libXtst-1.2.5.tar.xz"
  URL_HASH "SHA256=b50d4c25b97009a744706c1039c598f4d8e64910c9fde381994e1cae235d9242"
  LICENSE MIT
  CONFIGURE YES
  DEPENDS libxext libxi libx11
  INSTALLED_TARGETS "lib/libXtst.a=X11::Xtst"
  SYSTEM_PKGCONFIG "xtst:X11::Xtst"
  TARGETS X11::Xtst
  CHECK_HEADER X11/extensions/XTest.h
  CONFIGURE_ARGS
    "--disable-shared"
    "--enable-static"
    "--with-pic"
    "--disable-specs"
    "--without-xmlto"
    "--without-fop"
  CONFIGURE_CROSS "--host=@TRIPLE@"
)

# A static library, linked with what it calls: the libraries below it.
function(cme_adapt_libxtst source binary)
  if(TARGET X11::Xtst)
    set_property(TARGET X11::Xtst APPEND PROPERTY INTERFACE_LINK_LIBRARIES X11::Xext X11::Xi X11::X11)
  endif()
endfunction()
