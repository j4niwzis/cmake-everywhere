# Source fallback, with dependencies resolved through this build.
cme_declare_port(
  NAME glib PROVIDES GLIB glib-2.0 gobject-2.0 gio-2.0 gmodule-2.0 gthread-2.0
  VERSION 2.80.0 GITHUB_REPOSITORY GNOME/glib GIT_TAG 2.80.0
  LICENSE LGPL-2.1-or-later IMPORT meson DEPENDS pcre2 libffi zlib libiconv
  PATCHES "patches/0001-source-iconv-dependency.patch"
  IMPORT_TARGETS "glib-2.0=GLIB::glib" "gobject-2.0=GLIB::gobject" "gio-2.0=GLIB::gio"
                 "gmodule-2.0=GLIB::gmodule" "gthread-2.0=GLIB::gthread"
  SYSTEM_PKGCONFIG "glib-2.0:GLIB::glib" "gobject-2.0:GLIB::gobject" "gio-2.0:GLIB::gio"
                   "gmodule-2.0:GLIB::gmodule" "gthread-2.0:GLIB::gthread"
  LINK_NAMES "glib-2.0=GLIB::glib" "gobject-2.0=GLIB::gobject" "gio-2.0=GLIB::gio"
             "gmodule-2.0=GLIB::gmodule" "gthread-2.0=GLIB::gthread"
  TARGETS GLIB::glib GLIB::gobject GLIB::gio GLIB::gmodule GLIB::gthread CHECK_HEADER glib.h
  OPTIONS "tests false" "installed_tests false" "nls disabled"
          "libmount disabled" "selinux disabled" "xattr false" "documentation false"
          "introspection disabled" "sysprof disabled" "libelf disabled" "man-pages disabled"
)

function(cme_adapt_glib source binary)
  set(configured "${CMAKE_BINARY_DIR}/_cme/glib-probe")
  foreach(component glib gobject gio gmodule gthread)
    target_include_directories(glib_${component}-2.0 INTERFACE
      "$<BUILD_INTERFACE:${source}>" "$<BUILD_INTERFACE:${source}/glib>"
      "$<BUILD_INTERFACE:${source}/${component}>" "$<BUILD_INTERFACE:${configured}>"
      "$<BUILD_INTERFACE:${configured}/glib>")
  endforeach()
  set_property(GLOBAL PROPERTY CME_GLIB_MKENUMS "${configured}/gobject/glib-mkenums")
  find_package(Threads REQUIRED)
  target_link_libraries(glib_glib-2.0 INTERFACE pcre2-8 Iconv::Iconv Threads::Threads ${CMAKE_DL_LIBS})
  target_link_libraries(glib_gobject-2.0 INTERFACE GLIB::glib FFI::ffi)
  target_link_libraries(glib_gmodule-2.0 INTERFACE GLIB::glib ${CMAKE_DL_LIBS})
  target_link_libraries(glib_gthread-2.0 INTERFACE GLIB::glib Threads::Threads)
  target_link_libraries(glib_gio-2.0 INTERFACE GLIB::gobject GLIB::gmodule ZLIB::ZLIB)
endfunction()
