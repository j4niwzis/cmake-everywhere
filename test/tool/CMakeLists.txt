# A program for the machine doing the building, built by this build.
#
#   cmake -S test/tool -B build/tool -G Ninja \
#     -DCMAKE_PROJECT_TOP_LEVEL_INCLUDES=$PWD/cmake-everywhere.cmake
#
# What it proves: a project with its own toolchain becomes steps of this
# graph rather than a build inside a build step. Compile it and the compiler
# names in `ninja -t commands` are that project's, not this one's.
cmake_minimum_required(VERSION 3.24)
project(cme-tool LANGUAGES NONE)

cme_declare_port(
  NAME cme-stamp
  PROVIDES cme-stamp
  VERSION 1.0.0
  SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/stamp"
  # Whose machine the result is for: this one, the one doing the building.
  MACHINE build
  PROGRAMS "cme-stamp=cme::stamp"
  TARGETS cme::stamp)

find_package(cme-stamp REQUIRED)

add_custom_command(
  OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/stamp.txt"
  COMMAND cme::stamp "${CMAKE_CURRENT_BINARY_DIR}/stamp.txt"
  # The program is a file this waits for: an imported executable is a name
  # for something that exists, and what makes it is a step of this build.
  DEPENDS "${cme-stamp_PROGRAM}"
  VERBATIM)
add_custom_target(cme-tool ALL DEPENDS "${CMAKE_CURRENT_BINARY_DIR}/stamp.txt")

cme_report()
