# Written by tools/boost-ports.py. Do not edit: run the script again.
#
# A name for one part of Boost.Asio: the library with that part asked
# for. It builds nothing -- the part is a feature of boost-asio-core, and the
# target below is what that port produces when it is on.
cme_declare_port(
  NAME boost-asio-deadline-timer
  PROVIDES boost_asio_deadline_timer BoostAsioDeadlineTimer
  VERSION 1.92.0
  VIRTUAL YES
  FAMILY boost
  LICENSE BSL-1.0
  SYSTEM_PACKAGE boost_asio_deadline_timer
  TARGETS Boost::asio_deadline_timer
  DEPENDS boost-asio-core[deadline_timer]
)
