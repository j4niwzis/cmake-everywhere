# Written by tools/boost-ports.py from what boostorg/log
# declares. Do not edit: run the script again.
#
# One library out of Boost, on its own. FAMILY is what keeps it from being
# half of one Boost and half of another: every Boost port in a build is
# answered the same way, from the same place, at the same version.
cme_declare_port(
  NAME boost-log
  PROVIDES boost_log BoostLog
  VERSION 1.92.0
  FAMILY boost
  LICENSE BSL-1.0
  SYSTEM_PACKAGE boost_log
  TARGETS Boost::log
  DEPENDS boost-align boost-asio boost-assert boost-atomic boost-bind boost-config boost-core boost-date-time boost-exception boost-filesystem boost-function-types boost-fusion boost-interprocess boost-intrusive boost-io boost-iterator boost-move boost-mpl boost-optional boost-parameter boost-phoenix boost-predef boost-preprocessor boost-property-tree boost-proto boost-range boost-regex boost-smart-ptr boost-spirit boost-system boost-thread boost-throw-exception boost-type-index boost-type-traits boost-utility boost-winapi boost-xpressive
)

# Where the sources come from, which is the one thing about a Boost library
# that is worth a choice. One repository each is the small download when a
# project uses one or two of them; the release archive is one download of
# everything, which is faster from about the tenth library and is the whole
# of it either way.
if(CME_BOOST_ARCHIVE)
  cme_port_source(boost-log
    SOURCE_FROM boost-archive SOURCE_SUBDIR libs/log)
else()
  cme_port_source(boost-log
    GITHUB_REPOSITORY boostorg/log
    GIT_TAG boost-1.92.0
    GIT_TAG_TEMPLATE "boost-@VERSION@")
endif()
