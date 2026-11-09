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
  VERSION 1.26.0
  GIT_REPOSITORY https://gitlab.freedesktop.org/wayland/wayland.git
  GIT_TAG 1.26.0
  GIT_TAG_TEMPLATE "@VERSION@"
  LICENSE MIT
  IMPORT meson
  # The scanner reads the protocol XML with expat, and the connection
  # marshals its arguments with libffi. Both are ports, and meson is handed
  # them before it looks at the machine.
  DEPENDS expat libffi
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
  # The connection marshals with libffi: built here, the libraries are
  # static, and whatever links wayland-client (or -server) links libffi too
  # -- else ffi_call and ffi_type_* were left undefined (SDL's video, in a
  # program's window).
  foreach(target wayland-client wayland-server)
    if(TARGET wayland_${target} AND TARGET FFI::ffi)
      target_link_libraries(wayland_${target} INTERFACE FFI::ffi)
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
  # The build machine's scanner (cme_prepare_wayland), as a target a
  # consumer that generates protocol code can be ordered after (SDL).
  if(CMAKE_CROSSCOMPILING AND NOT TARGET cme_wayland_scanner_for_this_machine)
    add_custom_target(cme_wayland_scanner_for_this_machine)
  endif()
endfunction()

# In a cross build, a wayland-scanner for the machine doing the building,
# before wayland is asked what it would build: its own cross build finds
# one by its .pc -- a native dependency, of its own version, whose program
# Meson looks for while it is set up -- and runs it on the build machine to
# write its protocol code. scanner.c and wayland-util.c, with expat's three
# sources (the expat port's tree and configuration), compiled by the build
# machine's compiler: a tool for this machine, as a probe is, not a library
# of the program's. SDL runs the same one.
function(cme_prepare_wayland source)
  if(NOT CMAKE_CROSSCOMPILING)
    return()
  endif()
  get_property(expat_source GLOBAL PROPERTY CME_SOURCE_DIR_expat)
  if(EXISTS "${expat_source}/expat/lib")
    set(expat_source "${expat_source}/expat")
  endif()
  set(expat_configured "${CMAKE_BINARY_DIR}/_deps/expat-build")
  set(cc "${CME_BUILD_MACHINE_C_COMPILER}")
  if(NOT cc)
    set(cc cc)
  endif()
  set(here "${CMAKE_BINARY_DIR}/_cme/wayland-scanner-for-this-machine.d")
  set(scanner "${here}/wayland-scanner")
  string(REPLACE "." ";" parts "${port_version}")
  list(GET parts 0 WAYLAND_VERSION_MAJOR)
  list(GET parts 1 WAYLAND_VERSION_MINOR)
  list(GET parts 2 WAYLAND_VERSION_MICRO)
  set(WAYLAND_VERSION "${port_version}")
  configure_file("${source}/src/wayland-version.h.in" "${here}/wayland-version.h" @ONLY)
  if(NOT EXISTS "${scanner}")
    execute_process(
      COMMAND "${cc}" -O2 -DXML_STATIC -o "${scanner}"
              "${source}/src/scanner.c" "${source}/src/wayland-util.c"
              "${expat_source}/lib/xmlparse.c" "${expat_source}/lib/xmlrole.c" "${expat_source}/lib/xmltok.c"
              "-I${here}" "-I${source}/src" "-I${expat_source}/lib" "-I${expat_configured}"
      RESULT_VARIABLE code OUTPUT_VARIABLE output ERROR_VARIABLE output)
    if(NOT code EQUAL 0)
      message(FATAL_ERROR "cmake-everywhere: the build machine's wayland-scanner did not compile\n${output}")
    endif()
  endif()
  # Its .pc, where wayland's setup looks for native dependencies.
  file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/_cme/wayland-pc")
  file(WRITE "${CMAKE_BINARY_DIR}/_cme/wayland-pc/wayland-scanner.pc"
       "# Written by cmake-everywhere: the build machine's wayland-scanner.\n"
       "wayland_scanner=${scanner}\n"
       "pkgdatadir=${source}/protocol\n"
       "Name: wayland-scanner\n"
       "Description: the build machine's wayland-scanner\n"
       "Version: ${port_version}\n")
  set_property(GLOBAL PROPERTY CME_WAYLAND_SCANNER_FOR_THIS_MACHINE "${scanner}")
endfunction()
