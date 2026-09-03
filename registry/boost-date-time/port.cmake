# Written by tools/boost-ports.py from what boostorg/date_time
# declares. Do not edit: run the script again.
#
# One library out of Boost, on its own. FAMILY is what keeps it from being
# half of one Boost and half of another: every Boost port in a build is
# answered the same way, from the same place, at the same version.
cme_declare_port(
  NAME boost-date-time
  PROVIDES boost_date_time BoostDateTime
  VERSION 1.92.0
  FAMILY boost
  LICENSE BSL-1.0
  SYSTEM_PACKAGE boost_date_time
  TARGETS Boost::date_time
  DEPENDS boost-algorithm boost-assert boost-config boost-core boost-io boost-lexical-cast boost-numeric-conversion boost-range boost-smart-ptr boost-throw-exception boost-tokenizer boost-type-traits boost-utility boost-winapi
)

# Where the sources come from, which is the one thing about a Boost library
# that is worth a choice. One repository each is the small download when a
# project uses one or two of them; the release archive is one download of
# everything, which is faster from about the tenth library and is the whole
# of it either way.
if(CME_BOOST_ARCHIVE)
  cme_port_source(boost-date-time
    SOURCE_FROM boost-archive SOURCE_SUBDIR libs/date_time)
else()
  cme_port_source(boost-date-time
    GITHUB_REPOSITORY boostorg/date_time
    GIT_TAG boost-1.92.0
    GIT_TAG_TEMPLATE "boost-@VERSION@")
endif()
