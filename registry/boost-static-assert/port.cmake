# Written by tools/boost-ports.py from what boostorg/static_assert
# declares. Do not edit: run the script again.
#
# One library out of Boost, on its own. FAMILY is what keeps it from being
# half of one Boost and half of another: every Boost port in a build is
# answered the same way, from the same place, at the same version.
cme_declare_port(
  NAME boost-static-assert
  PROVIDES boost_static_assert BoostStaticAssert
  VERSION 1.92.0
  FAMILY boost
  LICENSE BSL-1.0
  SYSTEM_PACKAGE boost_static_assert
  TARGETS Boost::static_assert
  DEPENDS boost-config
)


# Boost as C++20 modules, which is one switch for the whole of it: a library
# that has an interface unit builds it and defines BOOST_USE_MODULES, and one
# that has none is unaffected by being told. Said as a feature so that a
# consumer asks for it -- find_package(boost_pfr COMPONENTS modules) -- rather
# than setting an option that only works when it is set before whoever
# resolves the port first asks for it.
cme_port_feature(boost-static-assert modules
  SUMMARY "built as a C++20 module, and imported rather than included"
  OPTIONS "BOOST_USE_MODULES ON")
# Where the sources come from, which is the one thing about a Boost library
# that is worth a choice. One repository each is the small download when a
# project uses one or two of them; the release archive is one download of
# everything, which is faster from about the tenth library and is the whole
# of it either way.
if(CME_BOOST_ARCHIVE)
  cme_port_source(boost-static-assert
    SOURCE_FROM boost-archive SOURCE_SUBDIR libs/static_assert)
else()
  cme_port_source(boost-static-assert
    GITHUB_REPOSITORY boostorg/static_assert
    GIT_TAG boost-1.92.0
    GIT_TAG_TEMPLATE "boost-@VERSION@")
endif()
