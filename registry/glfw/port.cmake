# Missing upstream: a namespaced target. glfw exports a target called glfw,
# with no namespace, so a project cannot tell whether it is linking a target
# or a bare library name -- and a bare name is whatever the linker finds.
cme_declare_port(
  NAME glfw
  PROVIDES glfw3 glfw GLFW GLFW3
  VERSION 3.4
  GITHUB_REPOSITORY glfw/glfw
  GIT_TAG 3.4
  GIT_TAG_TEMPLATE "@VERSION@"
  LICENSE Zlib
  SYSTEM_PKGCONFIG "glfw3:glfw::glfw"
  LINK_NAMES "glfw=glfw::glfw" "glfw3=glfw::glfw"
  TARGETS glfw::glfw
  CHECK_HEADER GLFW/glfw3.h
  # A window library and none of the programs that show it off.
  OPTIONS
    "GLFW_BUILD_EXAMPLES OFF"
    "GLFW_BUILD_TESTS OFF"
    "GLFW_BUILD_DOCS OFF"
    "GLFW_INSTALL OFF"
)

# Which windowing systems it is built for. Both are on in glfw's own build
# on Linux, and each needs its headers present, so each is a feature: a
# machine that has the X11 headers and not the Wayland ones can still build
# the library it can use.
# Whether an installed glfw has a backend is a question about the library:
# the function that hands out that backend's display is in it when the
# backend was built and is not when it was not. It is asked of the library
# and not through a header -- glfw3.h does not declare these at all, and
# glfw3native.h declares them behind a macro and includes Xlib.h to do it,
# so asking that way asks whether this machine has X11's headers.
cme_port_feature(glfw x11
  SUMMARY "the X11 backend"
  DEFAULT YES
  OPTIONS "GLFW_BUILD_X11 ON"
  SYSTEM_SYMBOLS "glfwGetX11Display")
cme_port_feature(glfw wayland
  SUMMARY "the Wayland backend"
  DEFAULT YES
  OPTIONS "GLFW_BUILD_WAYLAND ON"
  SYSTEM_SYMBOLS "glfwGetWaylandDisplay")

cme_port_rule(glfw AT_LEAST_ONE_OF x11 wayland)

function(cme_adapt_glfw source binary)
  cme_alias(glfw::glfw glfw)
  cme_export_variable(glfw3 GLFW3_FOUND TRUE)
  cme_export_variable(glfw3 GLFW3_LIBRARY glfw::glfw)
  cme_export_variable(glfw3 GLFW3_LIBRARIES glfw::glfw)
  cme_export_variable(glfw3 GLFW3_INCLUDE_DIR "${source}/include")
  cme_export_variable(glfw3 GLFW3_INCLUDE_DIRS "${source}/include")
endfunction()

# The window system linked in rather than opened at run time.
#
# GLFW's way is to open libwayland-client or libX11 when it starts and ask
# for symbols by name, which is right for a library that must run wherever
# it is put -- and impossible in a program that has no loader in it. The
# patch names the symbols directly, and everything they come from becomes a
# dependency of this port rather than a file found later.
#
# EGL among them: a context here comes from the EGL this build links, which
# is Mesa's, and GLX is not built at all because it would want a libGL to
# open.
cme_port_feature(glfw linked-window-system
  SUMMARY "link the window system instead of opening it at run time"
  DEPENDS wayland "libxkbcommon[x11]" libx11 libxext libxrandr libxinerama
          libxi libxcursor libxcb mesa
  PATCHES patches/0001-link-the-window-system-rather-than-open-it.patch)
