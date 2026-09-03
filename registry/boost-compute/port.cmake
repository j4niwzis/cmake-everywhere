# Written by tools/boost-ports.py from what boostorg/compute
# declares. Do not edit: run the script again.
#
# One library out of Boost, on its own. FAMILY is what keeps it from being
# half of one Boost and half of another: every Boost port in a build is
# answered the same way, from the same place, at the same version.
cme_declare_port(
  NAME boost-compute
  PROVIDES boost_compute BoostCompute
  VERSION 1.92.0
  FAMILY boost
  LICENSE BSL-1.0
  SYSTEM_PACKAGE boost_compute
  TARGETS Boost::compute
  DEPENDS boost-algorithm boost-array boost-assert boost-atomic boost-chrono boost-config boost-core boost-filesystem boost-function boost-function-types boost-fusion boost-iterator boost-lexical-cast boost-mpl boost-optional boost-preprocessor boost-property-tree boost-proto boost-range boost-smart-ptr boost-thread boost-throw-exception boost-tuple boost-type-traits boost-typeof boost-utility boost-uuid
)

# Where the sources come from, which is the one thing about a Boost library
# that is worth a choice. One repository each is the small download when a
# project uses one or two of them; the release archive is one download of
# everything, which is faster from about the tenth library and is the whole
# of it either way.
if(CME_BOOST_ARCHIVE)
  cme_port_source(boost-compute
    SOURCE_FROM boost-archive SOURCE_SUBDIR libs/compute)
else()
  cme_port_source(boost-compute
    GITHUB_REPOSITORY boostorg/compute
    GIT_TAG boost-1.92.0
    GIT_TAG_TEMPLATE "boost-@VERSION@")
endif()
