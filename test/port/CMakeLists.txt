# One library, on its own.
#
#   cmake -S test/port -B build/one -G Ninja \
#     -DCMAKE_PROJECT_TOP_LEVEL_INCLUDES=.../cmake-everywhere.cmake \
#     -DCME_PORT_PACKAGE=Freetype -DCME_PORT_TARGETS=Freetype::Freetype
#
# Nothing is included and nothing is called: what is being checked is that
# the port resolves, that whatever it needs resolves under it, and that the
# targets it says it produces exist and can be linked. A port that has rotted
# fails here rather than inside somebody's project.

cmake_minimum_required(VERSION 3.24)
project(cme-port LANGUAGES C CXX)

if(NOT CME_PORT_PACKAGE)
  message(FATAL_ERROR "Set CME_PORT_PACKAGE to the name to look for")
endif()

# A port does not have to come from a registry. Given a file of
# cme_declare_port() calls, this is a project carrying its own.
if(CME_PORT_DECLARE)
  include("${CME_PORT_DECLARE}")
endif()

if(CME_PORT_COMPONENTS)
  find_package(${CME_PORT_PACKAGE} REQUIRED COMPONENTS ${CME_PORT_COMPONENTS})
else()
  find_package(${CME_PORT_PACKAGE} REQUIRED)
endif()

# Again, the way a second library in a real build would ask. Asking for what
# is already here has to be silent: a caller that is told to run cmake again
# for something it was given the first time is a build that never finishes.
if(CME_PORT_COMPONENTS)
  find_package(${CME_PORT_PACKAGE} REQUIRED COMPONENTS ${CME_PORT_COMPONENTS})
else()
  find_package(${CME_PORT_PACKAGE} REQUIRED)
endif()

# A port may name the header its consumers include. Then that is what is
# compiled, because a library whose headers are on nobody's interface links
# perfectly well and cannot be used: xz keeps its API directory PRIVATE and
# hands it out at install time, so a check that only links says yes to a
# library nothing can include.
set(cme_port_source "${CMAKE_CURRENT_SOURCE_DIR}/main.cc")
if(CME_PORT_INCLUDE)
  set(cme_port_source "${CMAKE_CURRENT_BINARY_DIR}/include-check.cc")
  file(WRITE "${cme_port_source}"
    "#include <cstdio>\n#include <${CME_PORT_INCLUDE}>\n"
    "int main() { std::printf(\"included and linked\\n\"); return 0; }\n")
endif()

add_executable(cme-port "${cme_port_source}")
foreach(target IN LISTS CME_PORT_TARGETS)
  if(NOT TARGET ${target})
    message(FATAL_ERROR
      "the ${CME_PORT_PACKAGE} port says it produces ${target}, and it does "
      "not exist after find_package")
  endif()
  target_link_libraries(cme-port PRIVATE ${target})
endforeach()

cme_report()
