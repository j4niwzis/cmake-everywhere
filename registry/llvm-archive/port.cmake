# All of LLVM as it is published, in one file.
#
# Nothing is built from this port. Two things are built out of it -- the
# compiler libraries Mesa's drivers translate shaders with, and the C++
# runtime a program links -- and both are directories inside it, so this is
# what they say their sources are inside of.
#
# The archive rather than the repository, because the repository is the
# history of LLVM: gigabytes, of which one revision is wanted. The archive is
# a hundred and sixty megabytes, fetched once and kept.
cme_declare_port(
  NAME llvm-archive
  PROVIDES llvm_archive
  VERSION 22.1.8
  SOURCE_ONLY YES
  LICENSE Apache-2.0-WITH-LLVM-exception
  URL "https://github.com/llvm/llvm-project/releases/download/llvmorg-22.1.8/llvm-project-22.1.8.src.tar.xz"
  URL_HASH "SHA256=922f1817a0df7b1489272d18134ee0087a8b068828f87ac63b9861b1a9965888"
)
