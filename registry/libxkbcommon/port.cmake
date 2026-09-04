# What a key press means.
#
# A window system hands over a scancode and a modifier state; turning that
# into a symbol is a keymap, and this is what reads one. Under Wayland the
# compositor sends the keymap itself, as text down a file descriptor, so
# nothing on disk is needed -- which is what a program with no files of its
# own beside it requires. Under X the keymap is fetched from the server
# through xkb, which is why the X half is a feature rather than always on.
cme_declare_port(
  NAME libxkbcommon
  PROVIDES xkbcommon XKBCommon
  VERSION 1.11.0
  GITHUB_REPOSITORY xkbcommon/libxkbcommon
  GIT_TAG xkbcommon-1.11.0
  GIT_TAG_TEMPLATE "xkbcommon-@VERSION@"
  LICENSE MIT
  IMPORT meson
  IMPORT_TARGETS "xkbcommon=XKBCommon::xkbcommon"
  SYSTEM_PKGCONFIG "xkbcommon:XKBCommon::xkbcommon"
  LINK_NAMES "xkbcommon=XKBCommon::xkbcommon"
  TARGETS XKBCommon::xkbcommon
  CHECK_HEADER xkbcommon/xkbcommon.h
  # Nothing that runs: the tools are for a terminal, the documentation needs
  # doxygen, and the registry is for listing layouts in a settings panel.
  OPTIONS
    "enable-x11 false"
    "enable-wayland false"
    "enable-docs false"
    "enable-tools false"
    "enable-bash-completion false"
    "enable-xkbregistry false"
)

cme_port_feature(libxkbcommon x11
  SUMMARY "reading the keymap from an X server"
  DEPENDS libxcb
  OPTIONS "enable-x11 true"
  IMPORT_TARGETS "xkbcommon-x11=XKBCommon::x11")
