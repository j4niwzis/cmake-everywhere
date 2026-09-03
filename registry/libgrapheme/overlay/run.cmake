# One of libgrapheme's own programs, run for what it prints.
#
# Each of them writes a table of Unicode properties to its standard output
# and says nothing about where that should go: the library's Makefile
# redirects it. A build step here is a list of arguments rather than a shell
# command, and there is nowhere in that list to put a redirection, so this
# script is what holds it.
if(NOT DEFINED TOOL OR NOT DEFINED OUT OR NOT DEFINED WHERE)
  message(FATAL_ERROR "run.cmake wants TOOL, OUT and WHERE")
endif()
get_filename_component(directory "${OUT}" DIRECTORY)
file(MAKE_DIRECTORY "${directory}")
execute_process(
  COMMAND "${TOOL}"
  # The programs read the Unicode data by a path relative to where they are
  # run, so where they are run is the library's own tree.
  WORKING_DIRECTORY "${WHERE}"
  OUTPUT_FILE "${OUT}"
  RESULT_VARIABLE code
  ERROR_VARIABLE trouble)
if(NOT code EQUAL 0)
  file(REMOVE "${OUT}")
  message(FATAL_ERROR "${TOOL} failed (${code})\n${trouble}")
endif()
