# Written by tools/boost-ports.py. Do not edit: run the script again.
#
# All of Boost as it is published, in one file. Nothing is built from this
# port and nothing asks for it by name: it is what the other Boost ports say
# their sources are inside of, when CME_BOOST_ARCHIVE is on.
cme_declare_port(
  NAME boost-archive
  PROVIDES boost_archive
  VERSION 1.92.0
  SOURCE_ONLY YES
  LICENSE BSL-1.0
  URL "https://github.com/boostorg/boost/releases/download/boost-1.92.0/boost-1.92.0-cmake.tar.xz"
  URL_HASH "SHA256=9bed76128d4e46755dbe818487788c6fceb6f72b378f4daa49b7e1e600d9088d"
)
