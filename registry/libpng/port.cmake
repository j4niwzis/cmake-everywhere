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
    "SKIP_INSTALL_ALL ON"
    "PNG_SHARED OFF"
    "PNG_STATIC ON"
    "PNG_TESTS OFF"
    "PNG_TOOLS OFF"
    "PNG_FRAMEWORK OFF"
  SYSTEM_PKGCONFIG "libpng:PNG::PNG"
  GIT_TAG_TEMPLATE "v@VERSION@"
  LICENSE libpng-2.0
  # What this library answers to when something asks the linker for it by
  # name. A bare -l finds whatever is installed; a target is an archive
  # with a path.
  LINK_NAMES
    "png=PNG::PNG"
    "png16=PNG::PNG"
  # What a consumer links. Said here so that something other than a
  # human can check that the port still produces it.
  TARGETS PNG::PNG
  CHECK_HEADER png.h
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
  cme_build_includes(png_static "${source}" "${binary}")
endfunction()
