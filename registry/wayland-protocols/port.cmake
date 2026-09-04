# The protocols a Wayland client speaks beyond the core: xdg-shell for a
# window that a compositor manages, and the handful beside it for pointer
# constraints, idle inhibition and fractional scale.
#
# Data, not a library. What it carries is XML, and what reads the XML is
# wayland-scanner, which writes the C a client compiles. So nothing here is
# built, and what a consumer needs is the directory.
#
# Always fetched rather than taken from the machine: a few hundred kilobytes
# of protocol descriptions, and what the machine has is a version of them
# that has nothing to do with the compositor a program will actually meet.
cme_declare_port(
  NAME wayland-protocols
  PROVIDES wayland-protocols WaylandProtocols
  VERSION 1.45
  GIT_REPOSITORY https://gitlab.freedesktop.org/wayland/wayland-protocols.git
  GIT_TAG 1.45
  GIT_TAG_TEMPLATE "@VERSION@"
  LICENSE MIT
  SOURCE_ONLY YES
)

function(cme_adapt_wayland-protocols source binary)
  # Where the XML is. A consumer generates its bindings from these with the
  # scanner the wayland port hands it.
  cme_export_variable(WaylandProtocols WAYLAND_PROTOCOLS_DIR "${source}")
  cme_export_variable(WaylandProtocols WAYLAND_PROTOCOLS_FOUND TRUE)
endfunction()
