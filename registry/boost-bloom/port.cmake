# Written by tools/boost-ports.py from what boostorg/bloom
# declares. Do not edit: run the script again.
#
# One library out of Boost, on its own. FAMILY is what keeps it from being
# half of one Boost and half of another: every Boost port in a build is
# answered the same way, from the same place, at the same version.
cme_declare_port(
  NAME boost-bloom
  PROVIDES boost_bloom BoostBloom
  VERSION 1.92.0
  FAMILY boost
  LICENSE BSL-1.0
  SYSTEM_PACKAGE boost_bloom
  TARGETS Boost::bloom
  DEPENDS boost-assert boost-config boost-container-hash boost-core boost-throw-exception boost-type-traits
)

# Where the sources come from, which is the one thing about a Boost library
# that is worth a choice. One repository each is the small download when a
# project uses one or two of them; the release archive is one download of
# everything, which is faster from about the tenth library and is the whole
# of it either way.
if(CME_BOOST_ARCHIVE)
  cme_port_source(boost-bloom
    SOURCE_FROM boost-archive SOURCE_SUBDIR libs/bloom)
else()
  cme_port_source(boost-bloom
    GITHUB_REPOSITORY boostorg/bloom
    GIT_TAG boost-1.92.0
    GIT_TAG_TEMPLATE "boost-@VERSION@")
endif()
