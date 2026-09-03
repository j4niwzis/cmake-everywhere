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
cme_port_feature(glfw x11
  SUMMARY "the X11 backend"
  DEFAULT YES
  OPTIONS "GLFW_BUILD_X11 ON"
  SYSTEM_SYMBOLS "glfwGetX11Display:GLFW/glfw3.h")
cme_port_feature(glfw wayland
  SUMMARY "the Wayland backend"
  DEFAULT YES
  OPTIONS "GLFW_BUILD_WAYLAND ON"
  SYSTEM_SYMBOLS "glfwGetWaylandDisplay:GLFW/glfw3.h")

cme_port_rule(glfw AT_LEAST_ONE_OF x11 wayland)

function(cme_adapt_glfw source binary)
  cme_alias(glfw::glfw glfw)
  cme_export_variable(glfw3 GLFW3_FOUND TRUE)
  cme_export_variable(glfw3 GLFW3_LIBRARY glfw::glfw)
  cme_export_variable(glfw3 GLFW3_LIBRARIES glfw::glfw)
  cme_export_variable(glfw3 GLFW3_INCLUDE_DIR "${source}/include")
  cme_export_variable(glfw3 GLFW3_INCLUDE_DIRS "${source}/include")
endfunction()
