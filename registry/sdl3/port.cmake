# SDL 3: a window, input, and a GL, GLES or Vulkan surface to draw into, on
# Linux (X11 and Wayland), Windows, macOS, Android and iOS -- behind one API.
#
# Missing upstream: nothing but a stable target name. SDL builds its static
# library as SDL3-static and exports SDL3::SDL3-static; SDL3::SDL3 is what
# SDL3Config.cmake makes of whichever of the shared and static libraries an
# installation has, and a subdirectory build has no SDL3Config.cmake. A
# consumer writes SDL3::SDL3 either way, so it is made here.
# Which desktop windowing systems SDL is built for is said, not found: each
# is a feature of this port -- x11, wayland -- and a feature asked for is
# built here with what it needs, as every port's dependency is; a feature
# not asked for is off, whatever this machine happens to have. With neither,
# on Linux, SDL is its console build (no desktop windows; its offscreen and
# dummy video drivers), which is what SDL documents for that case -- and
# SDL_UNIX_CONSOLE_BUILD only lets SDL configure with no windowing system,
# it turns off none that a feature turned on.
cme_declare_port(
  NAME sdl3
  PROVIDES SDL3 sdl3
  VERSION 3.4.16
  GITHUB_REPOSITORY libsdl-org/SDL
  GIT_TAG release-3.4.16
  GIT_TAG_TEMPLATE "release-@VERSION@"
  LICENSE Zlib
  SYSTEM_PKGCONFIG "sdl3:SDL3::SDL3"
  LINK_NAMES "SDL3=SDL3::SDL3"
  TARGETS SDL3::SDL3
  CHECK_HEADER SDL3/SDL.h
  # The library, linked into the program, and nothing that shows it off.
  #
  # Which windowing systems, audio servers and graphics APIs it supports is
  # left to SDL: it looks for each one's headers and enables what it finds,
  # and it loads their libraries at run time rather than linking them, so a
  # program built with X11 and Wayland support runs on a machine that has
  # only one of them. That is the behaviour SDL documents and distributions
  # rely on, and choosing here would only take support away.
  # Not exported from the build tree: it links targets of the consumer's
  # build (the X11 ports are compiled there), which no export set holds.
  PATCHES "patches/0003-no-build-tree-export.patch"
  OPTIONS
    "CME_SDL_NO_BUILD_TREE_EXPORT ON"
    "SDL_SHARED OFF"
    "SDL_STATIC ON"
    "SDL_TEST_LIBRARY OFF"
    "SDL_TESTS OFF"
    "SDL_EXAMPLES OFF"
    "SDL_INSTALL OFF"
    "SDL_DISABLE_INSTALL ON"
    "SDL_DISABLE_INSTALL_DOCS ON"
    "SDL_X11 OFF"
    "SDL_WAYLAND OFF"
    "SDL_UNIX_CONSOLE_BUILD ON"
)

# Wayland: libwayland (the client, its EGL glue and its cursors, and the
# scanner that generates the protocols SDL speaks), libxkbcommon, and EGL's
# headers -- SDL loads libEGL and links nothing of it. SDL asks pkg-config
# for them and runs the scanner for its version while it configures; the
# patch has it take these ports' targets instead, and the scanner as the
# program its protocol code is generated with when the build reaches it.
cme_port_feature(sdl3 wayland
  SUMMARY "the Wayland video backend, with Wayland, xkbcommon and EGL's headers built here"
  DEPENDS wayland xkbcommon egl-headers
  OPTIONS "SDL_WAYLAND ON" "SDL_WAYLAND_SHARED OFF" "SDL_WAYLAND_LIBDECOR OFF" "CME_SDL_XKBCOMMON_VERSION 1.7.0"
  PATCHES "patches/0001-wayland-from-cme-ports.patch")

# X11: Xlib and the extensions SDL's X11 backend uses -- Xext, which it
# needs, and Xcursor, XInput 2, Xfixes, XRandR, Xrender, the screen saver
# extension and XTest, which it takes where they are -- each X.org library
# built here from its release, with xcb under Xlib. SDL looks for them with
# FindX11 and in the system's include directories; the patch has it take
# these ports' targets, and their prefixes for the headers.
cme_port_feature(sdl3 x11
  SUMMARY "the X11 video backend, with Xlib and its extensions built here"
  DEPENDS libx11 libxext libxcursor libxi libxfixes libxrandr libxrender libxscrnsaver libxtst
  OPTIONS "SDL_X11 ON" "SDL_X11_SHARED OFF"
  PATCHES "patches/0002-x11-from-cme-ports.patch")

function(cme_adapt_sdl3 source binary)
  if(NOT TARGET SDL3::SDL3)
    cme_alias(SDL3::SDL3 SDL3-static)
  endif()
  cme_export_variable(SDL3 SDL3_FOUND TRUE)
  cme_export_variable(SDL3 SDL3_LIBRARIES SDL3::SDL3)
  cme_export_variable(SDL3 SDL3_INCLUDE_DIRS "${source}/include")
endfunction()
