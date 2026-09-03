# Written by tools/boost-ports.py from what boostorg/graph_parallel
# declares. Do not edit: run the script again.
#
# One library out of Boost, on its own. FAMILY is what keeps it from being
# half of one Boost and half of another: every Boost port in a build is
# answered the same way, from the same place, at the same version.
cme_declare_port(
  NAME boost-graph-parallel
  PROVIDES boost_graph_parallel BoostGraphParallel
  VERSION 1.92.0
  FAMILY boost
  LICENSE BSL-1.0
  SYSTEM_PACKAGE boost_graph_parallel
  TARGETS Boost::graph_parallel
  DEPENDS boost-assert boost-concept-check boost-config boost-container-hash boost-core boost-detail boost-dynamic-bitset boost-filesystem boost-foreach boost-function boost-graph boost-iterator boost-lexical-cast boost-mpi boost-mpl boost-optional boost-property-map boost-property-map-parallel boost-random boost-serialization boost-smart-ptr boost-tuple boost-type-traits boost-variant
  ARRANGEMENT BOOST_ENABLE_MPI
)

# Where the sources come from, which is the one thing about a Boost library
# that is worth a choice. One repository each is the small download when a
# project uses one or two of them; the release archive is one download of
# everything, which is faster from about the tenth library and is the whole
# of it either way.
if(CME_BOOST_ARCHIVE)
  cme_port_source(boost-graph-parallel
    SOURCE_FROM boost-archive SOURCE_SUBDIR libs/graph_parallel)
else()
  cme_port_source(boost-graph-parallel
    GITHUB_REPOSITORY boostorg/graph_parallel
    GIT_TAG boost-1.92.0
    GIT_TAG_TEMPLATE "boost-@VERSION@")
endif()
