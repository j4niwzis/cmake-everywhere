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
# Boost::asio itself is all three.
#
# Which of them Boost::asio is made of is a feature here, and the two that
# cost another library are off unless they are asked for. Linking
# Boost::asio_core instead would be the other way to say it, but it is not a
# way anything gets to choose: Beast names Boost::asio, and a project that
# uses Beast over a socket was building Boost.Context -- assembly per
# architecture -- for coroutines nothing in it calls.
cme_declare_port(
  NAME boost-asio
  PROVIDES boost_asio BoostAsio
  VERSION 1.92.0
  FAMILY boost
  LICENSE BSL-1.0
  SYSTEM_PACKAGE boost_asio
  TARGETS Boost::asio
  VIRTUAL YES
  DEPENDS boost-asio-deadline-timer boost-asio-spawn
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
