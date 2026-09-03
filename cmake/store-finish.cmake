# Put a finished entry in place, or throw it away.
#
# Run as a script at the end of the commands that fill an entry:
#
#   cmake -Dfrom=<temporary> -Dto=<entry> -P cmake/store-finish.cmake
#
# An entry is built under a temporary name and moved into place in one step,
# because a reader has no way to tell a directory being written from one that
# is finished. A rename is that one step.
#
# Two builds may finish the same entry at the same time, and they are the same
# entry -- the name is a hash of everything that decides what is in it. So
# the second one to arrive throws its copy away rather than replacing a
# directory somebody may be reading.

if(NOT from OR NOT to)
  message(FATAL_ERROR "store-finish: from and to are both needed")
endif()

if(EXISTS "${to}/complete")
  file(REMOVE_RECURSE "${from}")
  return()
endif()

file(TOUCH "${from}/complete")
get_filename_component(parent "${to}" DIRECTORY)
file(MAKE_DIRECTORY "${parent}")
file(RENAME "${from}" "${to}" RESULT status NO_REPLACE)
if(NOT status STREQUAL "NO_ERROR")
  # Somebody else got there between the check and the rename, which is the
  # only thing that can have happened and is not a problem.
  file(REMOVE_RECURSE "${from}")
endif()
