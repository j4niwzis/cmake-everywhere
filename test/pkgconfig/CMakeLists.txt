# A project that asks pkg-config, on a machine told to build everything.
#
# Nothing here mentions cmake-everywhere, and nothing here is written the way
# this repository asks projects to write things: it is the shape a thousand
# existing CMakeLists have. The question is whether such a project gets an
# answer -- and with CME_SYSTEM=NEVER the only answer available is a library
# built from a port, so if this links, a pkg-config call was answered by
# something that is not pkg-config.
cmake_minimum_required(VERSION 3.24)
project(cme-pkgconfig LANGUAGES C CXX)

find_package(PkgConfig REQUIRED)
pkg_check_modules(ZLIB REQUIRED IMPORTED_TARGET zlib)

add_executable(cme-pkgconfig main.cc)
target_link_libraries(cme-pkgconfig PRIVATE PkgConfig::ZLIB)

# And the other half: without REQUIRED the question is "does this machine
# have it", which is a question about the machine. Nothing may be built to
# answer it, so a module nobody could have is simply not found.
pkg_check_modules(NOBODY there-is-no-library-by-this-name)
if(NOBODY_FOUND)
  message(FATAL_ERROR
    "a library that does not exist was found, which means an optional "
    "pkg-config call was answered by building something")
endif()

# And asked again, the way a library this build adds asks it.
#
# FindPkgConfig is a find module, and a find module is read again every time
# it is found: this second call re-runs the file, which defines
# pkg_check_modules over the one that answers here. Installing the answer
# once meant it lasted until the first fetched library asked PkgConfig for
# itself -- skiff does -- and everything after that went to pkg-config.
#
# The runner has zlib, so a call that reached pkg-config would be answered
# and would link. What tells them apart is the answer: this one hands back
# targets, and pkg-config hands back paths and -l names.
find_package(PkgConfig REQUIRED)
pkg_check_modules(AGAIN REQUIRED IMPORTED_TARGET zlib)
if(NOT "ZLIB::ZLIB" IN_LIST AGAIN_LIBRARIES)
  message(FATAL_ERROR
    "the second pkg_check_modules was answered by pkg-config: "
    "AGAIN_LIBRARIES is `${AGAIN_LIBRARIES}` rather than the port's target")
endif()

add_executable(cme-pkgconfig-again main.cc)
target_link_libraries(cme-pkgconfig-again PRIVATE PkgConfig::AGAIN)
