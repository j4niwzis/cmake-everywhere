# Wuffs as sources, because that is what asks for it.
#
# Wuffs ships the way stb does: one C file that is the whole standard library,
# compiled by whoever uses it with macros saying which codecs to keep. Skia
# compiles it with BASE, GIF and LZW and nothing else, which is a build of
# Wuffs that only the build doing it can make -- there is no library on any
# machine that was compiled with exactly that set, and one that was compiled
# with all of it is a larger thing than what is wanted.
#
# So the port's result is the tree, and the skia port says
#
#   TREES "third_party/externals/wuffs=wuffs-sources"
#
# The mirror rather than the language repository: what Skia builds is the
# released C file, and this is the repository that carries only that, at the
# commit Skia names.
cme_declare_port(
  NAME wuffs-sources
  PROVIDES wuffs-sources
  VERSION 0.3.0
  URL "https://github.com/google/wuffs-mirror-release-c/archive/e3f919ccfe3ef542cfc983a82146070258fb57f8.tar.gz"
  URL_HASH "SHA256=e849dab1f372f16b782ba7528e7f70281e35425bd2d644c92a36fb95909f98db"
  LICENSE Apache-2.0
  SOURCE_ONLY YES
)
