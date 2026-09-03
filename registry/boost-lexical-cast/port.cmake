# Written by tools/boost-ports.py from what boostorg/lexical_cast
# declares. Do not edit: run the script again.
#
# One library out of Boost, on its own. FAMILY is what keeps it from being
# half of one Boost and half of another: every Boost port in a build is
# answered the same way, from the same place, at the same version.
cme_declare_port(
  NAME boost-lexical-cast
  PROVIDES boost_lexical_cast BoostLexicalCast
  VERSION 1.92.0
  FAMILY boost
  LICENSE BSL-1.0
  SYSTEM_PACKAGE boost_lexical_cast
  TARGETS Boost::lexical_cast
  DEPENDS boost-config boost-container boost-core boost-throw-exception
)

# Where the sources come from, which is the one thing about a Boost library
# that is worth a choice. One repository each is the small download when a
# project uses one or two of them; the release archive is one download of
# everything, which is faster from about the tenth library and is the whole
# of it either way.
if(CME_BOOST_ARCHIVE)
  cme_port_source(boost-lexical-cast
    SOURCE_FROM boost-archive SOURCE_SUBDIR libs/lexical_cast)
else()
  cme_port_source(boost-lexical-cast
    GITHUB_REPOSITORY boostorg/lexical_cast
    GIT_TAG boost-1.92.0
    GIT_TAG_TEMPLATE "boost-@VERSION@")
endif()
