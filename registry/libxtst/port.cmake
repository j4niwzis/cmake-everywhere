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
  IMPORT make
  DEPENDS libxext libxi libx11
  IMPORT_TARGETS "Xtst=X11::Xtst"
  SYSTEM_PKGCONFIG "xtst:X11::Xtst"
  TARGETS X11::Xtst
  CHECK_HEADER X11/Xlib.h X11/extensions/XTest.h
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
  # Its headers are its tree's (include/X11/extensions), compiled here.
  if(TARGET libxtst_Xtst)
    target_include_directories(libxtst_Xtst INTERFACE "$<BUILD_INTERFACE:${source}/include>")
    target_link_libraries(libxtst_Xtst INTERFACE X11::Xext X11::Xi X11::X11)
  endif()
endfunction()
