# Written by tools/boost-ports.py from what boostorg/asio
# declares. Do not edit: run the script again.
#
# One library out of Boost, on its own. FAMILY is what keeps it from being
# half of one Boost and half of another: every Boost port in a build is
# answered the same way, from the same place, at the same version.
#
# Boost::asio is three libraries: asio_core, which needs align, assert,
# config, system and throw_exception; asio_deadline_timer, which adds
# date_time; and asio_spawn, which adds context for stackful coroutines.
# Boost::asio itself is all three, and that is why Context and Date_Time are
# in this list.
#
# Taking less means linking Boost::asio_core, which is a choice for whoever
# writes the target_link_libraries -- and not one Beast leaves open: its own
# dependency list names Boost::asio.
cme_declare_port(
  NAME boost-asio
  PROVIDES boost_asio BoostAsio
  VERSION 1.92.0
  FAMILY boost
  LICENSE BSL-1.0
  SYSTEM_PACKAGE boost_asio
  TARGETS Boost::asio
  DEPENDS boost-align boost-assert boost-config boost-context boost-date-time boost-system boost-throw-exception
)

# Where the sources come from, which is the one thing about a Boost library
# that is worth a choice. One repository each is the small download when a
# project uses one or two of them; the release archive is one download of
# everything, which is faster from about the tenth library and is the whole
# of it either way.
if(CME_BOOST_ARCHIVE)
  cme_port_source(boost-asio
    SOURCE_FROM boost-archive SOURCE_SUBDIR libs/asio)
else()
  cme_port_source(boost-asio
    GITHUB_REPOSITORY boostorg/asio
    GIT_TAG boost-1.92.0
    GIT_TAG_TEMPLATE "boost-@VERSION@")
endif()
