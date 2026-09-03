# Written by tools/boost-ports.py from what boostorg/geometry
# declares. Do not edit: run the script again.
#
# One library out of Boost, on its own. FAMILY is what keeps it from being
# half of one Boost and half of another: every Boost port in a build is
# answered the same way, from the same place, at the same version.
cme_declare_port(
  NAME boost-geometry
  PROVIDES boost_geometry BoostGeometry
  VERSION 1.92.0
  FAMILY boost
  LICENSE BSL-1.0
  SYSTEM_PACKAGE boost_geometry
  TARGETS Boost::geometry
  DEPENDS boost-algorithm boost-any boost-array boost-assert boost-concept-check boost-config boost-container boost-core boost-endian boost-function-types boost-fusion boost-graph boost-headers boost-integer boost-iterator boost-lexical-cast boost-math boost-move boost-mpl boost-multiprecision boost-numeric-conversion boost-polygon boost-predef boost-qvm boost-range boost-rational boost-serialization boost-thread boost-throw-exception boost-tokenizer boost-tuple boost-utility boost-variant boost-variant2
)

# Where the sources come from, which is the one thing about a Boost library
# that is worth a choice. One repository each is the small download when a
# project uses one or two of them; the release archive is one download of
# everything, which is faster from about the tenth library and is the whole
# of it either way.
if(CME_BOOST_ARCHIVE)
  cme_port_source(boost-geometry
    SOURCE_FROM boost-archive SOURCE_SUBDIR libs/geometry)
else()
  cme_port_source(boost-geometry
    GITHUB_REPOSITORY boostorg/geometry
    GIT_TAG boost-1.92.0
    GIT_TAG_TEMPLATE "boost-@VERSION@")
endif()
