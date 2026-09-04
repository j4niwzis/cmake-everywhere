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
  # The release archive, which carries the configure script: this is
  # autotools, and a checkout has only what generates one.
  URL "https://www.x.org/releases/individual/proto/xorgproto-2024.1.tar.xz"
  URL_HASH "SHA256=372225fd40815b8423547f5d890c5debc72e88b91088fbfb13158c20495ccb59"
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
