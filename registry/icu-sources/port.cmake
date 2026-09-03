# ICU as sources, because that is what asks for it.
#
# Nothing here builds ICU. What needs this is Skia: SkUnicode compiles
# fifteen files of ICU's bidirectional algorithm -- ubidi, ubidiln, ubidiwrt,
# ubidi_props and the handful of pieces those need -- straight into itself,
# out of third_party/externals/icu, with its own defines and its own symbol
# suffix so that the result cannot collide with an ICU the program also
# links. A built ICU cannot answer that: it is the wrong shape, and it is
# tens of megabytes where this is fifteen files.
#
# So the port's result is the tree. The skia port says
#
#   TREES "third_party/externals/icu=icu-sources"
#
# and the sources arrive the way every other source here arrives, as an
# archive with a digest of it, compiled by this build like everything else.
#
# The whole release archive rather than the fifteen files: what a port
# fetches is what upstream published, and a list of files picked out of it
# would be this registry's own idea of ICU rather than ICU.
cme_declare_port(
  NAME icu-sources
  PROVIDES icu-sources
  VERSION 77.1
  URL "https://github.com/unicode-org/icu/releases/download/release-77-1/icu4c-77_1-src.tgz"
  URL_HASH "SHA256=588e431f77327c39031ffbb8843c0e3bc122c211374485fa87dc5f3faff24061"
  LICENSE Unicode-3.0
  # There is nothing to build and nothing to find installed. An ICU on the
  # machine is a built library; this is a tree, and the two are not the same
  # thing even when they are the same version.
  SOURCE_ONLY YES
)
