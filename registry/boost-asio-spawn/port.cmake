# Written by tools/boost-ports.py. Do not edit: run the script again.
#
# A name for one part of Boost.Asio: the library with that part asked
# for. It builds nothing -- the part is a feature of boost-asio-core, and the
# target below is what that port produces when it is on.
cme_declare_port(
  NAME boost-asio-spawn
  PROVIDES boost_asio_spawn BoostAsioSpawn
  VERSION 1.92.0
  VIRTUAL YES
  FAMILY boost
  LICENSE BSL-1.0
  SYSTEM_PACKAGE boost_asio_spawn
  TARGETS Boost::asio_spawn
  DEPENDS boost-asio-core[spawn]
)


# Boost as C++20 modules, which is one switch for the whole of it: a library
# that has an interface unit builds it and defines BOOST_USE_MODULES, and one
# that has none is unaffected by being told. Said as a feature so that a
# consumer asks for it -- find_package(boost_pfr COMPONENTS modules) -- rather
# than setting an option that only works when it is set before whoever
# resolves the port first asks for it.
cme_port_feature(boost-asio-spawn modules
  SUMMARY "built as a C++20 module, and imported rather than included"
  OPTIONS "BOOST_USE_MODULES ON")