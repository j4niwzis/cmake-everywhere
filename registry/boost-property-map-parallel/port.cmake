# Written by tools/boost-ports.py from what boostorg/property_map_parallel
# declares. Do not edit: run the script again.
#
# One library out of Boost, on its own. FAMILY is what keeps it from being
# half of one Boost and half of another: every Boost port in a build is
# answered the same way, from the same place, at the same version.
cme_declare_port(
  NAME boost-property-map-parallel
  PROVIDES boost_property_map_parallel BoostPropertyMapParallel
  VERSION 1.92.0
  FAMILY boost
  LICENSE BSL-1.0
  SYSTEM_PACKAGE boost_property_map_parallel
  TARGETS Boost::property_map_parallel
  ARRANGEMENT BOOST_ENABLE_MPI
  DEPENDS boost-assert boost-bind boost-concept-check boost-config boost-function boost-mpi boost-mpl boost-multi-index boost-optional boost-property-map boost-serialization boost-smart-ptr boost-type-traits
)

# Where the sources come from, which is the one thing about a Boost library
# that is worth a choice. One repository each is the small download when a
# project uses one or two of them; the release archive is one download of
# everything, which is faster from about the tenth library and is the whole
# of it either way.
if(CME_BOOST_ARCHIVE)
  cme_port_source(boost-property-map-parallel
    SOURCE_FROM boost-archive SOURCE_SUBDIR libs/property_map_parallel)
else()
  cme_port_source(boost-property-map-parallel
    GITHUB_REPOSITORY boostorg/property_map_parallel
    GIT_TAG boost-1.92.0
    GIT_TAG_TEMPLATE "boost-@VERSION@")
endif()
