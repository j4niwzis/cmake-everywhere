# libxkbcommon: keymaps and keyboard state, as Wayland clients read the
# keyboard -- what SDL's Wayland backend turns key presses into characters
# with.
#
# Its keymap parser is a yacc grammar: building it needs bison (or byacc
# with backtracking) on the machine, as the build of any yacc project does.
cme_declare_port(
  NAME xkbcommon
  PROVIDES xkbcommon XKB libxkbcommon
  VERSION 1.7.0
  GITHUB_REPOSITORY xkbcommon/libxkbcommon
  GIT_TAG xkbcommon-1.7.0
  GIT_TAG_TEMPLATE "xkbcommon-@VERSION@"
  LICENSE MIT
  IMPORT meson
  IMPORT_TARGETS "xkbcommon=XKB::xkbcommon"
  SYSTEM_PKGCONFIG "xkbcommon:XKB::xkbcommon"
  LINK_NAMES "xkbcommon=XKB::xkbcommon"
  TARGETS XKB::xkbcommon
  CHECK_HEADER xkbcommon/xkbcommon.h
  # The library, nothing else: the tools, the X11 and Wayland extras, the
  # layout registry (which needs libxml2) and the documentation are not
  # what a consumer links.
  OPTIONS
    "enable-tools false"
    "enable-x11 false"
    "enable-wayland false"
    "enable-xkbregistry false"
    "enable-docs false"
    "enable-bash-completion false"
)
function(cme_adapt_xkbcommon source binary)
  # Its public headers are in the source tree's include/, which Meson gives
  # its own targets and not the consumers of the library.
  if(TARGET xkbcommon_xkbcommon)
    target_include_directories(xkbcommon_xkbcommon INTERFACE "$<BUILD_INTERFACE:${source}/include>")
  endif()
  cme_export_variable(xkbcommon XKBCOMMON_FOUND TRUE)
  cme_export_variable(xkbcommon XKBCOMMON_INCLUDE_DIRS "${source}/include")
endfunction()
