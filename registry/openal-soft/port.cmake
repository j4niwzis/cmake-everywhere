# Missing upstream: little. OpenAL Soft ships CMake and exports
# OpenAL::OpenAL; what is here is which backends to build, which is a
# decision about the machine rather than about the library.
cme_declare_port(
  NAME openal-soft
  PROVIDES OpenAL openal OPENAL
  VERSION 1.23.1
  GITHUB_REPOSITORY kcat/openal-soft
  GIT_TAG 1.23.1
  GIT_TAG_TEMPLATE "@VERSION@"
  LICENSE LGPL-2.0-or-later
  SYSTEM_PKGCONFIG "openal:OpenAL::OpenAL"
  LINK_NAMES "openal=OpenAL::OpenAL"
  TARGETS OpenAL::OpenAL
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
