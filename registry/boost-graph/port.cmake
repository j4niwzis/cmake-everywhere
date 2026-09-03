# Written by tools/boost-ports.py from what boostorg/graph
# declares. Do not edit: run the script again.
#
# One library out of Boost, on its own. FAMILY is what keeps it from being
# half of one Boost and half of another: every Boost port in a build is
# answered the same way, from the same place, at the same version.
cme_declare_port(
  NAME boost-graph
  PROVIDES boost_graph BoostGraph
  VERSION 1.92.0
  FAMILY boost
  LICENSE BSL-1.0
  SYSTEM_PACKAGE boost_graph
  TARGETS Boost::graph
  DEPENDS boost-algorithm boost-any boost-array boost-assert boost-bimap boost-concept-check boost-config boost-container-hash boost-core boost-detail boost-foreach boost-function boost-integer boost-iterator boost-lexical-cast boost-math boost-move boost-mpl boost-multi-index boost-multiprecision boost-numeric-conversion boost-optional boost-parameter boost-preprocessor boost-property-map boost-property-tree boost-random boost-range boost-regex boost-serialization boost-smart-ptr boost-spirit boost-throw-exception boost-tti boost-tuple boost-type-traits boost-typeof boost-unordered boost-utility boost-xpressive
)

# Where the sources come from, which is the one thing about a Boost library
# that is worth a choice. One repository each is the small download when a
# project uses one or two of them; the release archive is one download of
# everything, which is faster from about the tenth library and is the whole
# of it either way.
if(CME_BOOST_ARCHIVE)
  cme_port_source(boost-graph
    SOURCE_FROM boost-archive SOURCE_SUBDIR libs/graph)
else()
  cme_port_source(boost-graph
    GITHUB_REPOSITORY boostorg/graph
    GIT_TAG boost-1.92.0
    GIT_TAG_TEMPLATE "boost-@VERSION@")
endif()
