# Written by tools/boost-ports.py from what boostorg/beast
# declares. Do not edit: run the script again.
#
# One library out of Boost, on its own. FAMILY is what keeps it from being
# half of one Boost and half of another: every Boost port in a build is
# answered the same way, from the same place, at the same version.
#
# Beast's upstream target links Boost::asio, the aggregate target, but uses
# only its core. Keeping that spelling here would build Boost.Context and
# Boost.Date_Time for coroutine and timer parts Beast never calls, so the
# generated dependency is deliberately narrowed to Boost::asio_core.
cme_declare_port(
  NAME boost-beast
  PROVIDES boost_beast BoostBeast
  VERSION 1.92.0
  FAMILY boost
  LICENSE BSL-1.0
  SYSTEM_PACKAGE boost_beast
  TARGETS Boost::beast
  DEPENDS boost-asio-core boost-assert boost-bind boost-config boost-container boost-container-hash boost-core boost-endian boost-headers boost-intrusive boost-logic boost-mp11 boost-optional boost-smart-ptr boost-static-string boost-system boost-throw-exception boost-type-index boost-type-traits boost-winapi
)

# Where the sources come from, which is the one thing about a Boost library
# that is worth a choice. One repository each is the small download when a
# project uses one or two of them; the release archive is one download of
# everything, which is faster from about the tenth library and is the whole
# of it either way.
if(CME_BOOST_ARCHIVE)
  cme_port_source(boost-beast
    SOURCE_FROM boost-archive SOURCE_SUBDIR libs/beast)
else()
  cme_port_source(boost-beast
    GITHUB_REPOSITORY boostorg/beast
    GIT_TAG boost-1.92.0
    GIT_TAG_TEMPLATE "boost-@VERSION@")
endif()
