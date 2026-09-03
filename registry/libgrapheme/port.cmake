# The Unicode algorithms, in a few hundred kilobytes rather than a few tens
# of megabytes.
#
# What needs this is SkUnicode: where a word ends, where a line may break,
# which direction a run of text goes. Skia offers four sources for those --
# ICU, an ICU the client supplies, libgrapheme and ICU4X -- and they differ
# by two orders of magnitude in what they cost, which is why the choice is
# named rather than made by whichever happens to be installed.
#
# A commit rather than a release. The last release is 2.0.2 from 2022 and it
# has no bidirectional algorithm; Skia's own build takes the same commit
# this does, and SkUnicode calls what is only in it.
cme_declare_port(
  NAME libgrapheme
  PROVIDES libgrapheme Libgrapheme LIBGRAPHEME
  VERSION 2.0.2
  # The archive of that commit rather than a clone of the repository: a
  # fixed number of bytes with a digest of them, which is what the rest of
  # this registry fetches where a project publishes archives.
  URL "https://github.com/FRIGN/libgrapheme/archive/c0cab63c5300fa12284194fbef57aa2ed62a94c0.tar.gz"
  URL_HASH "SHA256=b267ba0700b4feafd3038cfa412b3fbb9504a0e8bd870bf21a2dd17abe2302d4"
  OVERLAY overlay
  LICENSE ISC
  # No installed copy is named, and that is deliberate rather than an
  # omission: distributions package the release, and the release is not what
  # this is. A build that took theirs would be missing the bidirectional
  # algorithm, which is the part SkUnicode cannot do without, and nothing in
  # a .pc file says which of the two it is.
  # What a consumer links, said here so that something other than a human
  # can check that the port still produces it.
  TARGETS libgrapheme::libgrapheme
  # What -lgrapheme means, for a build that names its libraries the way a
  # linker does. Skia's own description of a system library is a group whose
  # libs are read out of it, and this is how that name becomes this target.
  LINK_NAMES "grapheme=libgrapheme::libgrapheme"
  CHECK_HEADER grapheme.h
)

function(cme_adapt_libgrapheme source binary)
  cme_export_variable(libgrapheme LIBGRAPHEME_FOUND TRUE)
  cme_export_variable(libgrapheme LIBGRAPHEME_LIBRARY libgrapheme::libgrapheme)
  cme_export_variable(libgrapheme LIBGRAPHEME_LIBRARIES libgrapheme::libgrapheme)
  cme_export_variable(libgrapheme LIBGRAPHEME_INCLUDE_DIR
                      "${binary}/tree")
  cme_export_variable(libgrapheme LIBGRAPHEME_INCLUDE_DIRS
                      "${binary}/tree")
endfunction()
