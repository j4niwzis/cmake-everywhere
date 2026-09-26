# SDL 3: a window, input, and a GL, GLES or Vulkan surface to draw into, on
# Linux (X11 and Wayland), Windows, macOS, Android and iOS -- behind one API.
#
# Missing upstream: nothing but a stable target name. SDL builds its static
# library as SDL3-static and exports SDL3::SDL3-static; SDL3::SDL3 is what
# SDL3Config.cmake makes of whichever of the shared and static libraries an
# installation has, and a subdirectory build has no SDL3Config.cmake. A
# consumer writes SDL3::SDL3 either way, so it is made here.
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
  OPTIONS
    "SDL_SHARED OFF"
    "SDL_STATIC ON"
    "SDL_TEST_LIBRARY OFF"
    "SDL_TESTS OFF"
    "SDL_EXAMPLES OFF"
    "SDL_INSTALL OFF"
    "SDL_DISABLE_INSTALL ON"
    "SDL_DISABLE_INSTALL_DOCS ON"
)

function(cme_adapt_sdl3 source binary)
  if(NOT TARGET SDL3::SDL3)
    cme_alias(SDL3::SDL3 SDL3-static)
  endif()
  cme_export_variable(SDL3 SDL3_FOUND TRUE)
  cme_export_variable(SDL3 SDL3_LIBRARIES SDL3::SDL3)
  cme_export_variable(SDL3 SDL3_INCLUDE_DIRS "${source}/include")
endfunction()
