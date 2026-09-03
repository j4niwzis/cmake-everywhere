# The build cmake-everywhere gives a library whose own build is a POSIX
# Makefile.
#
# libgrapheme is nine C files and the programs that write six of their
# headers: gen/word.c reads data/WordBreakProperty.txt and prints the table
# src/word.c compiles. The Makefile does that with BUILD_CC for the programs
# and CC for the library, which is the whole of what has to be arranged
# here -- a program that prints a table has to run on the machine doing the
# building, whatever machine is being built for.
#
# Nothing is written into the fetched sources. The library's own files
# include their generated headers as "../gen/word.h", a path relative to the
# file that includes it, so the sources are copied next to the headers
# rather than the headers put next to the sources.
cmake_minimum_required(VERSION 3.24)
project(libgrapheme LANGUAGES C)

set(upstream "${CME_UPSTREAM_SOURCE_DIR}")
if(NOT upstream)
  message(FATAL_ERROR "libgrapheme: nothing said where the sources are")
endif()

# The six tables that are generated, named after the program that writes
# each and the source file that includes it.
set(tables bidirectional case character line sentence word)

# This project, configured a second time for the machine doing the building.
# Only the programs are built then, and they are the only thing that build
# produces.
option(LIBGRAPHEME_GENERATORS_ONLY
       "Build only the programs that write the tables" OFF)

foreach(table IN LISTS tables)
  add_executable(libgrapheme-gen-${table}
                 "${upstream}/gen/${table}.c" "${upstream}/gen/util.c")
  set_target_properties(libgrapheme-gen-${table} PROPERTIES
                        OUTPUT_NAME "${table}")
  target_include_directories(libgrapheme-gen-${table} PRIVATE "${upstream}")
  target_compile_definitions(libgrapheme-gen-${table} PRIVATE _DEFAULT_SOURCE)
  target_compile_features(libgrapheme-gen-${table} PRIVATE c_std_99)
endforeach()

if(LIBGRAPHEME_GENERATORS_ONLY)
  return()
endif()

# Where the library is compiled from: its own sources, beside the headers
# that are written here.
set(tree "${CMAKE_CURRENT_BINARY_DIR}/tree")
set(sources bidirectional case character line sentence utf8 util word)
foreach(name IN LISTS sources)
  configure_file("${upstream}/src/${name}.c" "${tree}/src/${name}.c" COPYONLY)
  list(APPEND compiled "${tree}/src/${name}.c")
endforeach()
configure_file("${upstream}/src/util.h" "${tree}/src/util.h" COPYONLY)
configure_file("${upstream}/grapheme.h" "${tree}/grapheme.h" COPYONLY)
# Not generated: the types the generated tables are written in terms of.
configure_file("${upstream}/gen/types.h" "${tree}/gen/types.h" COPYONLY)

if(CMAKE_CROSSCOMPILING)
  # The programs built above are for the machine being built for and cannot
  # be run here, so the same project is configured again with nothing said
  # about a toolchain, which is what makes it a build for this machine.
  include(ExternalProject)
  foreach(table IN LISTS tables)
    list(APPEND byproducts
         "${CMAKE_CURRENT_BINARY_DIR}/generators/${table}")
  endforeach()
  ExternalProject_Add(libgrapheme-generators
    SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}"
    BINARY_DIR "${CMAKE_CURRENT_BINARY_DIR}/generators"
    CMAKE_ARGS "-DLIBGRAPHEME_GENERATORS_ONLY=ON"
               "-DCME_UPSTREAM_SOURCE_DIR=${upstream}"
               "-DCMAKE_BUILD_TYPE=Release"
    INSTALL_COMMAND ""
    BUILD_BYPRODUCTS ${byproducts}
    USES_TERMINAL_BUILD OFF)
  set(generators "${CMAKE_CURRENT_BINARY_DIR}/generators")
endif()

foreach(table IN LISTS tables)
  if(CMAKE_CROSSCOMPILING)
    set(tool "${generators}/${table}")
    set(waits_for libgrapheme-generators)
  else()
    set(tool "$<TARGET_FILE:libgrapheme-gen-${table}>")
    set(waits_for libgrapheme-gen-${table})
  endif()
  add_custom_command(
    OUTPUT "${tree}/gen/${table}.h"
    COMMAND "${CMAKE_COMMAND}"
            "-DTOOL=${tool}"
            "-DOUT=${tree}/gen/${table}.h"
            "-DWHERE=${upstream}"
            -P "${CMAKE_CURRENT_SOURCE_DIR}/run.cmake"
    DEPENDS ${waits_for}
    COMMENT "libgrapheme: writing gen/${table}.h from the Unicode data"
    VERBATIM)
  list(APPEND generated "${tree}/gen/${table}.h")
endforeach()

add_library(grapheme STATIC ${compiled} ${generated})
add_library(libgrapheme::libgrapheme ALIAS grapheme)
target_include_directories(grapheme PUBLIC "$<BUILD_INTERFACE:${tree}>")
target_compile_definitions(grapheme PRIVATE _DEFAULT_SOURCE)
target_compile_features(grapheme PUBLIC c_std_99)
set_target_properties(grapheme PROPERTIES POSITION_INDEPENDENT_CODE ON)
