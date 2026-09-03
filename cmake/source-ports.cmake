# Read by CMake at the start of every project() call in the configuration --
# this project's, and every library's that this build adds.
#
# It is here rather than beside the fetching because of when it has to
# happen. A library says what it needs in cme-ports.cmake, and that has to be
# read before anything in the library asks for it. CPM fetches a tree and
# adds it in one call, so after that call the library has already asked;
# CMAKE_PROJECT_INCLUDE_BEFORE lands inside the tree, before its first line
# runs, at whatever depth it is.
#
# A library that uses cmake-everywhere needs none of this: its own
# cme_declare_port calls are in its CMakeLists and run at the same moment.

if(NOT CME_SOURCE_PORTS)
  return()
endif()

foreach(cme_ports_file "cme-port.cmake" "cme-ports.cmake"
                       ".cme/port.cmake" ".cme/ports.cmake")
  if(NOT EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/${cme_ports_file}")
    continue()
  endif()
  get_property(cme_ports_read GLOBAL PROPERTY CME_READ_PORTS)
  if("${CMAKE_CURRENT_SOURCE_DIR}/${cme_ports_file}" IN_LIST cme_ports_read)
    continue()
  endif()
  set_property(GLOBAL APPEND PROPERTY CME_READ_PORTS
    "${CMAKE_CURRENT_SOURCE_DIR}/${cme_ports_file}")
  get_filename_component(cme_ports_directory
    "${CMAKE_CURRENT_SOURCE_DIR}/${cme_ports_file}" DIRECTORY)
  if(CMAKE_CURRENT_SOURCE_DIR STREQUAL CMAKE_SOURCE_DIR)
    # The project's own, which is the project speaking for itself: it is
    # exported and installed like anything else it declares.
    set_property(GLOBAL PROPERTY CME_PORT_ORIGIN "")
  else()
    set_property(GLOBAL PROPERTY CME_PORT_ORIGIN
      "the source in ${CMAKE_CURRENT_SOURCE_DIR}")
  endif()
  set_property(GLOBAL PROPERTY CME_PORT_DIRECTORY "${cme_ports_directory}")
  message(STATUS "cmake-everywhere: reading ${cme_ports_file} carried by "
                 "${CMAKE_CURRENT_SOURCE_DIR}")
  include("${CMAKE_CURRENT_SOURCE_DIR}/${cme_ports_file}")
  set_property(GLOBAL PROPERTY CME_PORT_ORIGIN "")
  set_property(GLOBAL PROPERTY CME_PORT_DIRECTORY "")
endforeach()
