# Put a finished entry in place, or throw it away.
#
#   cmake -Dfrom=<temporary> -Dto=<entry> -P cmake/store-finish.cmake
#
# An entry is built under a temporary name and moved into place in one step,
# because a reader has no way to tell a directory being written from one that
# is finished. A rename is that one step.
#
# Two builds may finish the same entry at the same time, and they are the same
# entry -- the name is a hash of everything that decides what is in it. So the
# second one to arrive throws its copy away rather than replacing a directory
# somebody may be reading.

if(NOT from OR NOT to)
  message(FATAL_ERROR "store-finish: from and to are both needed")
endif()

if(NOT EXISTS "${from}")
  message(FATAL_ERROR
    "store-finish: there is nothing at ${from} to put in the store")
endif()

if(EXISTS "${to}/complete")
  file(REMOVE_RECURSE "${from}")
  return()
endif()

file(TOUCH "${from}/complete")
get_filename_component(parent "${to}" DIRECTORY)
file(MAKE_DIRECTORY "${parent}")

# Without NO_REPLACE, which is not a thing every filesystem can do: CMake
# asks for it with renameat2 and overlayfs answers that it may not, which is
# how this failed everywhere at once on a machine whose working directory is
# an overlay.
#
# A rename onto a directory that has something in it fails anyway, so the
# race that NO_REPLACE closes is closed by the filesystem: whoever gets there
# first wins and the other is told the destination is occupied. The only
# difference is that the answer has to be read rather than assumed.
file(RENAME "${from}" "${to}" RESULT status)
if(status STREQUAL "0")
  message(STATUS "cmake-everywhere: kept ${to}")
  return()
endif()

if(EXISTS "${to}/complete")
  # Somebody else finished the same entry while this one was being written,
  # and it is the same entry: the name is a hash of what is in it.
  message(STATUS "cmake-everywhere: ${to} was already there")
  file(REMOVE_RECURSE "${from}")
  return()
endif()

message(FATAL_ERROR
  "cmake-everywhere: cannot put ${from} at ${to}: ${status}")
