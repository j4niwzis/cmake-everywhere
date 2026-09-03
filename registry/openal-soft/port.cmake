# Missing upstream: little. OpenAL Soft ships CMake and exports
# OpenAL::OpenAL; what is here is which backends to build, which is a
# decision about the machine rather than about the library.
# 1.24.3 rather than the newest.
#
# 1.23.1 names uint8_t without including <cstdint>, which libstdc++ 15 no
# longer reaches for it, so that one does not compile. 1.25 marks the mixer
# [[clang::nonblocking]], and libstdc++'s std::variant throws and holds
# static locals, so clang refuses to infer the attribute through it -- an
# effect of pairing a library that was annotated against libc++ with the
# other standard library.
#
# 1.24.3 has the include and not the annotations.
# openal-soft links its bundled fmt as alsoft::fmt, an alias for a static
# library in its own tree. An entry written before aliases were resolved
# names that alias, and a build reading such an entry is told to link a
# target nothing defines. Entries are addressed by, among other things, the
# digest of this file -- so this paragraph is also what makes those entries
# unreachable.
cme_declare_port(
  NAME openal-soft
  PROVIDES OpenAL openal OPENAL
  VERSION 1.24.3
  GITHUB_REPOSITORY kcat/openal-soft
  GIT_TAG 1.24.3
  GIT_TAG_TEMPLATE "@VERSION@"
  LICENSE LGPL-2.0-or-later
  SYSTEM_PKGCONFIG "openal:OpenAL::OpenAL"
  LINK_NAMES "openal=OpenAL::OpenAL"
  PATCHES patches/0001-fmt-uses-malloc-and-free.patch
  TARGETS OpenAL::OpenAL
  CHECK_HEADER AL/al.h
  # A library, and nothing beside it: the examples and the utilities are
  # programs, and the router is a second library nobody asked for.
  OPTIONS
    "LIBTYPE STATIC"
    "ALSOFT_EXAMPLES OFF"
    "ALSOFT_UTILS OFF"
    "ALSOFT_TESTS OFF"
    "ALSOFT_INSTALL_EXAMPLES OFF"
    "ALSOFT_INSTALL_UTILS OFF"
    "ALSOFT_BACKEND_OBOE OFF"
    "ALSOFT_BACKEND_OPENSL OFF"
)

# Which way sound leaves the machine. Every one of these is a backend OpenAL
# Soft can be built with or without, and a backend that is not there is a
# device that cannot be opened -- which is a run-time silence rather than a
# build error, so it is worth asking for deliberately.
cme_port_feature(openal-soft oboe
  SUMMARY "the Android backend, through Oboe"
  DEPENDS oboe
  OPTIONS "ALSOFT_BACKEND_OBOE ON")

cme_port_feature(openal-soft opensl
  SUMMARY "the older Android backend, OpenSL ES"
  OPTIONS "ALSOFT_BACKEND_OPENSL ON")

# On Android, one of the two above rather than none.
#
# The backends this library is built with are the devices it can open, and
# the two Android ones are off in the OPTIONS above because they are wrong
# everywhere else. A build for Android that named no backend got a library
# that opens nothing, which is silence at run time and no error at any time.
# Oboe is the current one and the one Android's own documentation points at;
# OpenSL ES is what it replaced.
#
# android is a platform, so this is not a request anybody makes or refuses:
# it is on because the build is for Android.
cme_port_feature(openal-soft android
  SUMMARY "the Android audio backend"
  IMPLIES oboe)

cme_port_feature(openal-soft pipewire
  SUMMARY "PipeWire"
  OPTIONS "ALSOFT_BACKEND_PIPEWIRE ON")

cme_port_feature(openal-soft pulseaudio
  SUMMARY "PulseAudio"
  OPTIONS "ALSOFT_BACKEND_PULSEAUDIO ON")

cme_port_feature(openal-soft alsa
  SUMMARY "ALSA"
  OPTIONS "ALSOFT_BACKEND_ALSA ON")

function(cme_adapt_openal-soft source binary)
  cme_alias(OpenAL::OpenAL OpenAL)
  cme_export_variable(OpenAL OPENAL_FOUND TRUE)
  cme_export_variable(OpenAL OPENAL_LIBRARY OpenAL::OpenAL)
  cme_export_variable(OpenAL OPENAL_LIBRARIES OpenAL::OpenAL)
  cme_export_variable(OpenAL OPENAL_INCLUDE_DIR "${source}/include/AL")
  cme_export_variable(OpenAL OPENAL_INCLUDE_DIRS
    "${source}/include;${source}/include/AL")
endfunction()
