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
#
# This file downloads CMake and runs it. That is the same thing
# cme_port_from_url does, and it is refused there without a digest, in as
# many words: "that file is CMake this build will read, from somewhere that
# is not this project". A rule a project keeps for others and not for itself
# is not a rule, so the same one applies here.
#
# Set CME_VERSION to the revision you want and CME_SHA256 to the digest of
# its archive. The build says both, every time, so a project that has not
# pinned this has been told.

set(CME_VERSION "d59422a1284aded6cb008536a8e17ef43e0b3ecd" CACHE STRING
  "cmake-everywhere revision: a commit, a tag, or a branch you are following")
set(CME_SHA256 "" CACHE STRING
  "The digest of that revision's archive, or empty to take what arrives")
set(CME_SOURCE_DIR "${CMAKE_BINARY_DIR}/_cme-registry" CACHE PATH
  "Where the registry is unpacked")

if(NOT CME_VERSION MATCHES "^[0-9a-f]${40}$" AND NOT CME_SHA256)
  message(WARNING
    "cmake-everywhere: this build takes ${CME_VERSION}, which is a name "
    "rather than a revision, and no CME_SHA256 to check what arrives. What "
    "resolves your dependencies is then whatever that name points at today, "
    "while everything it resolves is pinned. Set CME_VERSION to a commit.")
endif()

if(NOT EXISTS "${CME_SOURCE_DIR}/cmake-everywhere.cmake")
  set(archive "${CMAKE_BINARY_DIR}/cme-${CME_VERSION}.tar.gz")
  message(STATUS "cmake-everywhere: fetching ${CME_VERSION}")
  if(CME_SHA256)
    file(DOWNLOAD
      "https://github.com/j4niwzis/cmake-everywhere/archive/${CME_VERSION}.tar.gz"
      "${archive}" STATUS status EXPECTED_HASH SHA256=${CME_SHA256})
  else()
    file(DOWNLOAD
      "https://github.com/j4niwzis/cmake-everywhere/archive/${CME_VERSION}.tar.gz"
      "${archive}" STATUS status)
  endif()
  list(GET status 0 code)
  if(NOT code EQUAL 0)
    list(GET status 1 reason)
    message(FATAL_ERROR "cmake-everywhere: cannot fetch ${CME_VERSION}: ${reason}")
  endif()
  file(SHA256 "${archive}" CME_FETCHED_SHA256)
  file(ARCHIVE_EXTRACT INPUT "${archive}"
       DESTINATION "${CMAKE_BINARY_DIR}/_cme-unpack")
  file(GLOB unpacked "${CMAKE_BINARY_DIR}/_cme-unpack/*")
  list(GET unpacked 0 root)
  file(REMOVE_RECURSE "${CME_SOURCE_DIR}")
  file(RENAME "${root}" "${CME_SOURCE_DIR}")
  set(CME_FETCHED_SHA256 "${CME_FETCHED_SHA256}" CACHE INTERNAL
      "The digest of the archive this build took")
endif()

include("${CME_SOURCE_DIR}/cmake-everywhere.cmake")
