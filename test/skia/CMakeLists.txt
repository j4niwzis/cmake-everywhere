# Skia, described by GN and built as CMake targets.
#
#   cmake -S test/skia -B build/skia -G Ninja \
#     -DCMAKE_PROJECT_TOP_LEVEL_INCLUDES=$PWD/cmake-everywhere.cmake
#
# With no components this is Skia as a CPU rasteriser and nothing else, which
# is the cheapest way to find out whether the GN description was read
# correctly. Add components once it does:
#
#   -DCME_FEATURES_skia="gl;png;freetype"

cmake_minimum_required(VERSION 3.24)

# Both languages: Skia is C++ and the libraries under it are C, and GN is
# told which compiler to describe the build for.
project(cme-skia LANGUAGES C CXX)

find_package(Skia REQUIRED)

add_executable(cme-skia main.cc)
target_link_libraries(cme-skia PRIVATE Skia::skia)
target_compile_features(cme-skia PRIVATE cxx_std_17)

# Linking proves the symbols were found somewhere. It does not prove they
# were found in the library this registry built -- a system copy would have
# satisfied the linker just as well and said nothing.
#
# So when a feature that brings a library is on, that library is asked for
# here as well and its version is compared at run time against the version
# the port pinned. The same library is reached, because the provider resolves
# a package once: if these disagree, Skia was linked against something else.
if("png" IN_LIST CME_FEATURES_skia)
  find_package(PNG REQUIRED)
  target_link_libraries(cme-skia PRIVATE PNG::PNG)
  target_compile_definitions(cme-skia PRIVATE
    CME_EXPECT_PNG="${PNG_VERSION}")
endif()

if("freetype" IN_LIST CME_FEATURES_skia)
  find_package(Freetype REQUIRED)
  target_link_libraries(cme-skia PRIVATE Freetype::Freetype)
  target_compile_definitions(cme-skia PRIVATE
    CME_EXPECT_FREETYPE="${Freetype_VERSION}")
endif()

cme_report()
