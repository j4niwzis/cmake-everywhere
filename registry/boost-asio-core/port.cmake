# Written by tools/boost-ports.py. Do not edit: run the script again.
#
# Boost.Asio, which upstream builds as four targets: this one, a part
# apiece for the two that need another library, and one that is all of them.
# The parts are features here -- they are built when they are asked for, and
# what they need comes with them -- so a project that asks for the core
# builds neither of the two.
cme_declare_port(
  NAME boost-asio-core
  PROVIDES boost_asio_core BoostAsioCore
  VERSION 1.92.0
  FAMILY boost
  LICENSE BSL-1.0
  SYSTEM_PACKAGE boost_asio
  TARGETS Boost::asio_core
  LINK_NAMES "Boost::asio=Boost::asio_core"
  DEPENDS boost-align boost-assert boost-config boost-system boost-throw-exception
  OPTIONS "BOOST_ASIO_DEADLINE_TIMER OFF" "BOOST_ASIO_SPAWN OFF"
  PATCHES 0001-let-a-build-say-which-parts-of-asio-it-wants.patch
)

cme_port_feature(boost-asio-core deadline_timer
  SUMMARY "Boost::asio_deadline_timer"
  DEFAULT NO
  DEPENDS boost-date-time
  OPTIONS "BOOST_ASIO_DEADLINE_TIMER ON"
  TARGETS Boost::asio_deadline_timer)

cme_port_feature(boost-asio-core spawn
  SUMMARY "Boost::asio_spawn"
  DEFAULT NO
  DEPENDS boost-context
  OPTIONS "BOOST_ASIO_SPAWN ON"
  TARGETS Boost::asio_spawn)

# Where the sources come from, the same choice as every other Boost port.
if(CME_BOOST_ARCHIVE)
  cme_port_source(boost-asio-core
    SOURCE_FROM boost-archive SOURCE_SUBDIR libs/asio)
else()
  cme_port_source(boost-asio-core
    GITHUB_REPOSITORY boostorg/asio
    GIT_TAG boost-1.92.0
    GIT_TAG_TEMPLATE "boost-@VERSION@")
endif()
