# Missing upstream: a CMake build, and a small sd-bus at all.
#
# What a program that talks to D-Bus wants is sd-bus, and what provides
# sd-bus is systemd -- a package that is not built as a dependency of
# anything and is not there on a machine that does not run it. basu is
# sd-bus taken out of systemd and nothing else, which is the thing to build
# when the system has none of the three libraries that carry sd-bus.
#
# It builds with Meson, so it is imported: configured on its own, asked what
# it would build, and built here. IMPORT meson, which is the same idea as
# IMPORT cmake and for the same reason.
cme_declare_port(
  NAME basu
  PROVIDES basu sd-bus sdbus
  VERSION 0.2.1
  GIT_REPOSITORY https://git.sr.ht/~emersion/basu
  GIT_TAG v0.2.1
  GIT_TAG_TEMPLATE "v@VERSION@"
  LICENSE LGPL-2.1-or-later
  IMPORT meson
  IMPORT_TARGETS "basu=basu::basu"
  # The three libraries that carry sd-bus, in the order a machine should be
  # asked about them: whichever is installed answers, and only a machine
  # with none of them builds this one. libsystemd is asked about last on
  # purpose -- it is the largest thing to pull in and the least likely to be
  # there for its own sake.
  SYSTEM_PKGCONFIG "basu|libelogind|libsystemd:basu::basu"
  # The header a program that wants sd-bus writes. basu installs it under
  # basu/, libsystemd and libelogind under systemd/, and this port answers
  # to both spellings -- so the one checked here is the one that works
  # whichever of them answered.
  CHECK_HEADER systemd/sd-bus.h
  TARGETS basu::basu
  # Two libraries it can be built against, neither of which it needs. A
  # machine that has them would otherwise decide what this port produces.
  OPTIONS
    "audit disabled"
    "libcap disabled"
)

function(cme_adapt_basu source binary)
  # Its headers are in the checkout under src/systemd, and a consumer
  # writes one of two things: <basu/sd-bus.h>, which is where basu installs
  # them, or <systemd/sd-bus.h>, which is where libsystemd and libelogind
  # install the same API. The directory is offered under both names, so a
  # program written for either builds against this.
  cme_header_prefix(root basu "${source}/src/systemd")
  cme_header_prefix(root systemd "${source}/src/systemd")
  target_include_directories(basu_basu INTERFACE "$<BUILD_INTERFACE:${root}>")

  # What the archives need from outside the project. Meson states the
  # external dependencies of a static library nowhere -- it puts them on
  # the command line of whatever links it, which here is us.
  find_package(Threads REQUIRED)
  target_link_libraries(basu_basu INTERFACE Threads::Threads)
  if(CMAKE_SYSTEM_NAME STREQUAL "Linux" AND NOT ANDROID)
    target_link_libraries(basu_basu INTERFACE m rt)
  endif()
endfunction()
