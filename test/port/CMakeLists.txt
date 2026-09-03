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

find_package(${CME_PORT_PACKAGE} REQUIRED)

add_executable(cme-port main.cc)
foreach(target IN LISTS CME_PORT_TARGETS)
  if(NOT TARGET ${target})
    message(FATAL_ERROR
      "the ${CME_PORT_PACKAGE} port says it produces ${target}, and it does "
      "not exist after find_package")
  endif()
  target_link_libraries(cme-port PRIVATE ${target})
endforeach()

cme_report()
