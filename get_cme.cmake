# Copy this file into your project and point CMAKE_PROJECT_TOP_LEVEL_INCLUDES
# at it, before project():
#
#   set(CMAKE_PROJECT_TOP_LEVEL_INCLUDES ${CMAKE_CURRENT_LIST_DIR}/cmake/get_cme.cmake)
#   project(app)
#   find_package(SndFile REQUIRED)
#   target_link_libraries(app PRIVATE SndFile::sndfile)
#
# A dependency provider may only be installed from a file named by that
# variable, which is why this is a variable and not a call.

set(CME_VERSION "main" CACHE STRING "cmake-everywhere revision to use")
set(CME_SOURCE_DIR "${CMAKE_BINARY_DIR}/_cme-registry" CACHE PATH
  "Where the registry is unpacked")

if(NOT EXISTS "${CME_SOURCE_DIR}/cmake-everywhere.cmake")
  set(archive "${CMAKE_BINARY_DIR}/cme-${CME_VERSION}.tar.gz")
  message(STATUS "cmake-everywhere: fetching ${CME_VERSION}")
  file(DOWNLOAD
    "https://github.com/j4niwzis/cmake-everywhere/archive/${CME_VERSION}.tar.gz"
    "${archive}" STATUS status)
  list(GET status 0 code)
  if(NOT code EQUAL 0)
    list(GET status 1 reason)
    message(FATAL_ERROR "cmake-everywhere: cannot fetch ${CME_VERSION}: ${reason}")
  endif()
  file(ARCHIVE_EXTRACT INPUT "${archive}"
       DESTINATION "${CMAKE_BINARY_DIR}/_cme-unpack")
  file(GLOB unpacked "${CMAKE_BINARY_DIR}/_cme-unpack/*")
  list(GET unpacked 0 root)
  file(REMOVE_RECURSE "${CME_SOURCE_DIR}")
  file(RENAME "${root}" "${CME_SOURCE_DIR}")
endif()

include("${CME_SOURCE_DIR}/cmake-everywhere.cmake")
