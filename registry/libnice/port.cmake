# Source fallback, with dependencies resolved through this build.
cme_declare_port(
  NAME libnice PROVIDES LibNice nice
  VERSION 0.1.23 GITHUB_REPOSITORY libnice/libnice GIT_TAG 0.1.23
  LICENSE MPL-1.1 IMPORT meson DEPENDS glib openssl
  PATCHES "patches/0001-native-codegen.patch"
  IMPORT_TARGETS "nice=LibNice::LibNice" SYSTEM_PKGCONFIG "nice:LibNice::LibNice"
  LINK_NAMES "nice=LibNice::LibNice" TARGETS LibNice::LibNice CHECK_HEADER nice/agent.h
  OPTIONS "gupnp disabled" "gstreamer disabled" "examples disabled"
          "tests disabled" "gtk_doc disabled" "introspection disabled" "crypto-library openssl"
)

function(cme_adapt_libnice source binary)
  cme_header_prefix(public nice "${source}/agent")
  target_include_directories(libnice_nice INTERFACE
    "$<BUILD_INTERFACE:${public}>" "$<BUILD_INTERFACE:${source}>" "$<BUILD_INTERFACE:${source}/nice>"
    "$<BUILD_INTERFACE:${CMAKE_BINARY_DIR}/_cme/libnice-probe>"
    "$<BUILD_INTERFACE:${CMAKE_BINARY_DIR}/_cme/libnice-probe/agent>")
  target_link_libraries(libnice_nice INTERFACE GLIB::gio GLIB::gthread OpenSSL::SSL OpenSSL::Crypto)
  cme_export_variable(LibNice LibNice_FOUND TRUE)
endfunction()

# GNOME's Meson module needs a host code generator, not an executable
# compiled for the Android target. The source GLib configures this Python
# tool at setup time; installed GLib supplies it through pkg-config.
function(cme_prepare_libnice source)
  get_property(codegen GLOBAL PROPERTY CME_GLIB_MKENUMS)
  set(options ${CME_OPTIONS_libnice})
  list(FILTER options EXCLUDE REGEX "^cme-mkenums ")
  if(codegen)
    list(APPEND options "cme-mkenums ${codegen}")
  endif()
  cme_options(libnice ${options})
endfunction()
