# Missing upstream: nothing. Wayland builds with Meson, which is not CMake,
# and that is the whole of it -- so it is imported: configured on its own,
# asked what it would build, and built here.
#
# What a machine that runs Wayland has installed is what this port should
# answer with, nearly always: a compositor is already using that copy, and
# a second one built here talks to the same socket with the same protocol.
# The source build is for the machine that has the headers of a Wayland it
# does not run, or none at all.
cme_declare_port(
  NAME wayland
  PROVIDES Wayland wayland
  VERSION 1.24.0
  GIT_REPOSITORY https://gitlab.freedesktop.org/wayland/wayland.git
  GIT_TAG 1.24.0
  GIT_TAG_TEMPLATE "@VERSION@"
  LICENSE MIT
  IMPORT meson
  IMPORT_TARGETS
    "wayland-client=Wayland::client"
    "wayland-server=Wayland::server"
    "wayland-cursor=Wayland::cursor"
    "wayland-egl=Wayland::egl"
    "wayland-scanner=Wayland::scanner"
  # All four come out of one package everywhere, so asking for all four is
  # asking whether that package is installed.
  SYSTEM_PKGCONFIG
    "wayland-client:Wayland::client"
    "wayland-server:Wayland::server"
    "wayland-cursor:Wayland::cursor"
    "wayland-egl:Wayland::egl"
  LINK_NAMES
    "wayland-client=Wayland::client"
    "wayland-server=Wayland::server"
    "wayland-cursor=Wayland::cursor"
    "wayland-egl=Wayland::egl"
  TARGETS Wayland::client Wayland::server Wayland::cursor Wayland::egl
  CHECK_HEADER wayland-client.h
  # What is not built: the documentation needs doxygen and xsltproc, the
  # tests need to run, and validating the protocol against its DTD needs
  # libxml2. None of that is in the library a consumer links.
  OPTIONS
    "documentation false"
    "tests false"
    "dtd_validation false"
)

function(cme_adapt_wayland source binary)
  # The protocol headers are generated, into the directory the project was
  # configured in, and every consumer includes one of them.
  set(configured "${CMAKE_BINARY_DIR}/_cme/wayland-probe")
  foreach(target wayland-client wayland-server wayland-cursor wayland-egl)
    if(TARGET wayland_${target})
      target_include_directories(wayland_${target} INTERFACE
        "$<BUILD_INTERFACE:${source}/src>"
        "$<BUILD_INTERFACE:${configured}/src>")
    endif()
  endforeach()
  if(TARGET wayland_wayland-cursor)
    target_include_directories(wayland_wayland-cursor INTERFACE
      "$<BUILD_INTERFACE:${source}/cursor>")
  endif()
  if(TARGET wayland_wayland-egl)
    target_include_directories(wayland_wayland-egl INTERFACE
      "$<BUILD_INTERFACE:${source}/egl>")
  endif()
  cme_export_variable(Wayland WAYLAND_FOUND TRUE)
  cme_export_variable(Wayland WAYLAND_LIBRARIES "Wayland::client")
  cme_export_variable(Wayland WAYLAND_CLIENT_LIBRARIES "Wayland::client")
  cme_export_variable(Wayland WAYLAND_INCLUDE_DIRS
                      "${source}/src;${configured}/src")
  # Where the protocol this speaks is written down, for a consumer that
  # generates bindings of its own -- which is what a Wayland client that
  # uses any protocol beyond the core does. The program that reads it is
  # the Wayland::scanner target, when this was built rather than found.
  cme_export_variable(Wayland WAYLAND_PROTOCOL_XML "${source}/protocol/wayland.xml")
endfunction()
