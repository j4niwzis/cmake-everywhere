# Copy headers a library wrote while it was building into the entry.
#
#   cmake -Dfrom=<directory> -Dto=<entry>/generated/<n> -P store-headers.cmake
#
# Most libraries write the headers they generate while they configure, and
# those are copied when the entry is described. Some write them while they
# build -- libsndfile makes its include directory, mpg123 fills one -- and at
# that moment there is nothing to copy. This runs afterwards, beside the
# commands that copy the archives.
#
# Recording the path instead is what a store must never do: a directory
# inside a build tree is true on the machine that wrote it and gone by the
# next build, so the entry misses every time, the library is rebuilt every
# time, and a fresh copy of the same useless entry is written on every run.

if(NOT from OR NOT to)
  message(FATAL_ERROR "store-headers: from and to are both needed")
endif()

get_filename_component(entry "${to}" DIRECTORY)
get_filename_component(entry "${entry}" DIRECTORY)

file(GLOB_RECURSE headers "${from}/*")
if(NOT IS_DIRECTORY "${from}" OR NOT headers)
  # The library said its headers would be here and they are not, so what
  # would be kept is a library nothing can be compiled against. The mark is
  # what store-finish reads before it publishes anything.
  message(STATUS
    "cmake-everywhere: ${from} is still not there after the build, so this "
    "is not kept")
  file(TOUCH "${entry}/incomplete")
  return()
endif()

file(COPY "${from}/" DESTINATION "${to}"
     PATTERN "CMakeFiles" EXCLUDE PATTERN ".git" EXCLUDE)
