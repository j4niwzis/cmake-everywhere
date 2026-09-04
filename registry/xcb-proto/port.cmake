# The X protocol, written down, and the program that turns it into C.
#
# Not a library: what this installs is the XML description of every X
# extension and the Python that reads it. libxcb is generated from both --
# its request and reply functions do not exist in its own tree -- so this is
# a dependency of a build rather than of a program.
#
# It is found the way libxcb finds it, through pkg-config: the file this
# installs says where the XML and the Python are, and libxcb's build reads
# those two paths out of it.
cme_declare_port(
  NAME xcb-proto
  PROVIDES xcb-proto
  VERSION 1.17.0
  # The release archive, which carries the configure script: this is
  # autotools, and a checkout has only what generates one.
  URL "https://xcb.freedesktop.org/dist/xcb-proto-1.17.0.tar.xz"
  URL_HASH "SHA256=2c1bacd2110f4799f74de6ebb714b94cf6f80fb112316b1219480fd22562148c"
  LICENSE MIT
  CONFIGURE YES
  # Nothing is compiled here, so there is nothing to import: the port exists
  # to put its prefix on the path where the next port looks.
  INSTALLED_TARGETS ""
  SYSTEM_PKGCONFIG "xcb-proto"
  CONFIGURE_CROSS "--host=@TRIPLE@"
)
