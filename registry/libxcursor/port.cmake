# X cursors: themes and animated cursors, from X.org's release tarball: an
# autotools build, configured and installed into a prefix of its own.
cme_declare_port(
  NAME libxcursor
  PROVIDES Xcursor libXcursor xcursor
  VERSION 1.2.3
  URL "https://xorg.freedesktop.org/archive/individual/lib/libXcursor-1.2.3.tar.xz"
  URL_HASH "SHA256=fde9402dd4cfe79da71e2d96bb980afc5e6ff4f8a7d74c159e1966afb2b2c2c0"
  LICENSE MIT
  CONFIGURE YES
  IMPORT make
  DEPENDS libxrender libxfixes libx11
  IMPORT_TARGETS "Xcursor=X11::Xcursor"
  SYSTEM_PKGCONFIG "xcursor:X11::Xcursor"
  TARGETS X11::Xcursor
  CHECK_HEADER X11/Xlib.h X11/Xcursor/Xcursor.h
  CONFIGURE_ARGS
    "--disable-shared"
    "--enable-static"
    "--with-pic"
  CONFIGURE_CROSS "--host=@TRIPLE@"
)

# A static library, linked with what it calls: the libraries below it.
function(cme_adapt_libxcursor source binary)
  # Its headers are its tree's (include/X11/extensions), compiled here.
  if(TARGET libxcursor_Xcursor)
    target_include_directories(libxcursor_Xcursor INTERFACE "$<BUILD_INTERFACE:${source}/include>")
    target_link_libraries(libxcursor_Xcursor INTERFACE X11::Xrender X11::Xfixes X11::X11)
  endif()
endfunction()
