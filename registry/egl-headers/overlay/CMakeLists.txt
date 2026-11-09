# The build cmake-everywhere gives EGL-Registry: its api/ directory, as an
# interface target. Nothing is compiled.
cmake_minimum_required(VERSION 3.24)
project(egl_headers LANGUAGES NONE)

add_library(egl_headers INTERFACE)
add_library(EGL::Headers ALIAS egl_headers)
target_include_directories(egl_headers INTERFACE "${CME_UPSTREAM_SOURCE_DIR}/api")
