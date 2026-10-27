cmake_minimum_required(VERSION 3.24)
project(cme-calls C)
# A cross target cannot use the host's .pc files. Require the parent build
# to supply every Meson dependency, including the aggregate openssl module.
file(MAKE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/empty-pkgconfig")
unset(ENV{PKG_CONFIG_PATH})
set(ENV{PKG_CONFIG_LIBDIR} "${CMAKE_CURRENT_BINARY_DIR}/empty-pkgconfig")
find_package(LibNice REQUIRED)
add_executable(cme-calls main.c)
target_link_libraries(cme-calls PRIVATE LibNice::LibNice)
