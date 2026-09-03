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

cme_report()
