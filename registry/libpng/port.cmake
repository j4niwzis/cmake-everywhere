# Missing upstream: dependencies resolved rather than assumed -- libpng calls
# find_package(ZLIB) and has no way to be handed one -- and a namespaced
# target.
cme_declare_port(
  NAME libpng
  PROVIDES PNG
  VERSION 1.6.44
  GITHUB_REPOSITORY pnggroup/libpng
  GIT_TAG v1.6.44
  DEPENDS zlib
  OPTIONS
    "PNG_SHARED OFF"
    "PNG_STATIC ON"
    "PNG_TESTS OFF"
    "PNG_TOOLS OFF"
    "PNG_FRAMEWORK OFF"
  SYSTEM_PKGCONFIG "libpng:PNG::PNG"
  GIT_TAG_TEMPLATE "v@VERSION@"
)

# libpng looks for zlib with find_package(ZLIB) inside its own CMakeLists,
# and that call is answered by the provider rather than by the project that
# asked for PNG. This is the whole point: the consumer says PNG and says it
# once.
function(cme_adapt_libpng source binary)
  cme_alias(PNG::PNG png_static)
  cme_export_variable(PNG PNG_FOUND TRUE)
  cme_export_variable(PNG PNG_LIBRARY PNG::PNG)
  cme_export_variable(PNG PNG_LIBRARIES PNG::PNG)
  cme_export_variable(PNG PNG_PNG_INCLUDE_DIR "${source};${binary}")
  cme_export_variable(PNG PNG_INCLUDE_DIR "${source};${binary}")
  cme_export_variable(PNG PNG_INCLUDE_DIRS "${source};${binary}")
  cme_export_variable(PNG PNG_VERSION_STRING 1.6.44)
  target_include_directories(png_static PUBLIC "${source}" "${binary}")
endfunction(  SYSTEM_PKGCONFIG "libpng:PNG::PNG"
)
