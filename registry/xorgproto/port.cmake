# The X protocol's headers: the constants, the structures and the wire
# format, and nothing that is compiled.
#
# Everything on the X side includes them -- libXau for the authority
# structures, libxcb for the core protocol, Mesa for the DRI3 and Present
# definitions -- and a machine that has X development files has them under
# one name or another. Built here it is a copy of the headers and no more.
cme_declare_port(
  NAME xorgproto
  PROVIDES xorgproto XorgProto
  VERSION 2024.1
  GIT_REPOSITORY https://gitlab.freedesktop.org/xorg/proto/xorgproto.git
  GIT_TAG xorgproto-2024.1
  GIT_TAG_TEMPLATE "xorgproto-@VERSION@"
  LICENSE MIT
  CONFIGURE YES
  # Headers, so nothing comes out as a target: what the ports after this one
  # need is the prefix it installs into, which they are handed.
  INSTALLED_TARGETS ""
  INSTALLED_INCLUDE include
  SYSTEM_PKGCONFIG "xproto"
  CHECK_HEADER X11/Xfuncproto.h
  CONFIGURE_CROSS "--host=@TRIPLE@"
)
