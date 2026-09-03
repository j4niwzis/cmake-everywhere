# A project that wants sd-bus, on a machine that has no sd-bus.
#
# Nothing here says which library provides it or how that library is built.
# With CME_SYSTEM=NEVER nothing installed can answer, so the only answer
# available is basu, whose build is Meson: if this links, a Meson project
# was configured, read, and built as part of this build.
cmake_minimum_required(VERSION 3.24)
project(cme-meson LANGUAGES C)

find_package(basu REQUIRED)

add_executable(cme-meson main.c)
target_link_libraries(cme-meson PRIVATE basu::basu)
