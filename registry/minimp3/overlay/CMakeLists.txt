# The build cmake-everywhere gives a library that has none.
#
# Nothing is written into the fetched sources: they are read from
# CME_UPSTREAM_SOURCE_DIR and the only file compiled is the one beside this
# CMakeLists. That keeps the overlay a normal CMake project and the upstream
# checkout exactly as it was downloaded.

cmake_minimum_required(VERSION 3.24)
project(minimp3 LANGUAGES C)

add_library(minimp3 STATIC minimp3.c)
add_library(minimp3::minimp3 ALIAS minimp3)
target_include_directories(minimp3 PUBLIC "${CME_UPSTREAM_SOURCE_DIR}")
target_compile_features(minimp3 PRIVATE c_std_11)
set_target_properties(minimp3 PROPERTIES POSITION_INDEPENDENT_CODE ON)
