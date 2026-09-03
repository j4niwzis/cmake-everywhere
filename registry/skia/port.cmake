# Missing upstream: CMake, in the sense this registry means it -- Skia builds
# with GN, and its own GN-to-CMake script says it is "not meant for any
# purpose beyond development" in an IDE.
#
# So GN is asked to describe the build and the description becomes CMake
# targets: see cmake/gn.cmake, which knows nothing about Skia. Everything
# below is Skia's own vocabulary, and that is the only Skia-specific thing
# here.
cme_declare_port(
  NAME skia
  PROVIDES Skia skia SKIA
  VERSION 0.0.0
  GITHUB_REPOSITORY google/skia
  # Skia has no releases; it has milestone branches. A commit is what a port
  # can pin, and this one is a placeholder until somebody chooses a milestone
  # deliberately: set CME_VERSION_skia or edit this.
  GIT_TAG main
  # The libraries Skia would otherwise carry copies of in third_party. Built
  # here, for this target, and handed to it below.
  DEPENDS zlib libpng libjpeg-turbo libwebp freetype
  GN_TARGETS "//:skia=Skia::skia"
  GN_ARGS
    "is_official_build=true"
    "is_component_build=false"
    "cc=\"@CC@\""
    "cxx=\"@CXX@\""
    "target_os=\"@TARGET_OS@\""
    "target_cpu=\"@TARGET_CPU@\""
    # Ganesh on GL. Vulkan wants the whole Vulkan and vk_video header
    # closure, which is a decision a consumer should make, not a default.
    "skia_use_gl=true"
    "skia_use_vulkan=false"
    "skia_use_dawn=false"
    "skia_use_metal=false"
    # Every one of these is a port in this registry.
    "skia_use_system_zlib=true"
    "skia_use_system_libpng=true"
    "skia_use_system_libjpeg_turbo=true"
    "skia_use_system_libwebp=true"
    "skia_use_system_freetype2=true"
    "skia_use_freetype=true"
    # Not built here, so not asked for from the system either.
    "skia_use_system_harfbuzz=false"
    "skia_use_harfbuzz=false"
    "skia_use_system_expat=false"
    "skia_use_expat=false"
    "skia_use_icu=false"
    "skia_use_wuffs=false"
    "skia_use_dng_sdk=false"
    "skia_use_piex=false"
    "skia_use_fontconfig=false"
    # The Android font manager reads the system font configuration through
    # ICU headers such as unicode/uchar.h.
    "skia_enable_fontmgr_android=false"
    "skia_enable_fontmgr_custom_directory=true"
    "skia_enable_fontmgr_custom_empty=true"
    "skia_enable_tools=false"
    "extra_cflags=[@DEP_INCLUDES@]"
    "extra_ldflags=[@DEP_LIBDIRS@]"
  # What GN ended up with, not what the command line asked for.
  GN_CONFIRM
    "skia_use_vulkan=false"
    "skia_use_system_zlib=true"
    "skia_use_system_freetype2=true"
)

function(cme_adapt_skia source binary)
  cme_export_variable(Skia SKIA_FOUND TRUE)
  cme_export_variable(Skia SKIA_LIBRARY Skia::skia)
  cme_export_variable(Skia SKIA_LIBRARIES Skia::skia)
  cme_export_variable(Skia SKIA_INCLUDE_DIR "${source}")
  cme_export_variable(Skia SKIA_INCLUDE_DIRS "${source}")
  # Skia is included as "include/core/SkCanvas.h", from the root of its own
  # checkout, which is why the root is the include directory.
  target_include_directories(skia_skia INTERFACE
    "$<BUILD_INTERFACE:${source}>")
endfunction()
