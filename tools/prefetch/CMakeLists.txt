# Fill a source cache for a build that will not have a network.
#
#   cmake -S tools/prefetch -B build/prefetch \
#     -DCMAKE_PROJECT_TOP_LEVEL_INCLUDES=$PWD/cmake-everywhere.cmake \
#     -DCPM_SOURCE_CACHE=$PWD/vendor \
#     -DCME_PREFETCH="skia;openal-soft;libsndfile" \
#     -DCME_FEATURES_skia="gl;png;freetype"
#
# Nothing is compiled. Each library named, and everything underneath it, is
# fetched into the cache and left there. The same features have to be asked
# for as the real build will ask for, because a feature is what brings a
# dependency -- fetching Skia without png does not fetch libpng, and the
# offline build would then stop at the first thing it could not reach.
#
# Afterwards the cache is a directory like any other: put it in an archive,
# ship it to the builder, and configure there with CME_OFFLINE=ON and
# CPM_SOURCE_CACHE pointing at it.

cmake_minimum_required(VERSION 3.24)
project(cme-prefetch LANGUAGES NONE)

if(NOT CPM_SOURCE_CACHE)
  message(FATAL_ERROR
    "Set CPM_SOURCE_CACHE to the directory to fill.")
endif()
if(CME_OFFLINE)
  message(FATAL_ERROR
    "CME_OFFLINE and prefetching are opposites: this is the run that needs "
    "the network.")
endif()

set(CME_FETCH_ONLY ON CACHE BOOL "" FORCE)

# The registry is read when the first find_package arrives, and this asks it
# questions before making one.
cme_load_registry()

if(NOT CME_PREFETCH)
  # Everything the registry has, which is what a mirror wants and rather more
  # than a project does.
  file(GLOB entries "${CME_REGISTRY}/*/port.cmake")
  set(CME_PREFETCH "")
  foreach(entry IN LISTS entries)
    get_filename_component(directory "${entry}" DIRECTORY)
    get_filename_component(name "${directory}" NAME)
    list(APPEND CME_PREFETCH "${name}")
  endforeach()
  message(STATUS "cmake-everywhere: prefetching the whole registry")
endif()

foreach(port IN LISTS CME_PREFETCH)
  cme_port_field(names ${port} PROVIDES)
  if(NOT names)
    message(FATAL_ERROR "cmake-everywhere: there is no port called ${port}")
  endif()
  list(GET names 0 package)
  find_package(${package} REQUIRED)
endforeach()

cme_report()
