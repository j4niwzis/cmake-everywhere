# Written by tools/boost-ports.py from what boostorg/dynamic_bitset
# declares. Do not edit: run the script again.
#
# One library out of Boost, on its own. FAMILY is what keeps it from being
# half of one Boost and half of another: every Boost port in a build is
# answered the same way, from the same place, at the same version.
cme_declare_port(
  NAME boost-dynamic-bitset
  PROVIDES boost_dynamic_bitset BoostDynamicBitset
  VERSION 1.92.0
  FAMILY boost
  LICENSE BSL-1.0
  SYSTEM_PACKAGE boost_dynamic_bitset
  TARGETS Boost::dynamic_bitset
  DEPENDS boost-assert boost-config boost-container-hash boost-core boost-throw-exception
)

# Where the sources come from, which is the one thing about a Boost library
# that is worth a choice. One repository each is the small download when a
# project uses one or two of them; the release archive is one download of
# everything, which is faster from about the tenth library and is the whole
# of it either way.
if(CME_BOOST_ARCHIVE)
  cme_port_source(boost-dynamic-bitset
    SOURCE_FROM boost-archive SOURCE_SUBDIR libs/dynamic_bitset)
else()
  cme_port_source(boost-dynamic-bitset
    GITHUB_REPOSITORY boostorg/dynamic_bitset
    GIT_TAG boost-1.92.0
    GIT_TAG_TEMPLATE "boost-@VERSION@")
endif()
