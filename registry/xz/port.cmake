# Missing upstream: the name CMake's own FindLibLZMA hands out. xz builds
# liblzma::liblzma and a great deal of CMake asks for LibLZMA::LibLZMA.
cme_declare_port(
  NAME xz
  PROVIDES LibLZMA liblzma LIBLZMA lzma
  VERSION 5.6.3
  GITHUB_REPOSITORY tukaani-project/xz
  GIT_TAG v5.6.3
  GIT_TAG_TEMPLATE "v@VERSION@"
  LICENSE 0BSD
  SYSTEM_PKGCONFIG "liblzma:LibLZMA::LibLZMA"
  LINK_NAMES "lzma=LibLZMA::LibLZMA"
  TARGETS LibLZMA::LibLZMA
  # Only the library. xz, xzdec, lzmadec and lzmainfo are programs, and a
  # program is not what anything here links.
  OPTIONS
    "XZ_TOOL_XZ OFF"
    "XZ_TOOL_XZDEC OFF"
    "XZ_TOOL_LZMADEC OFF"
    "XZ_TOOL_LZMAINFO OFF"
    "XZ_TOOL_SCRIPTS OFF"
    "XZ_DOC OFF"
    "XZ_NLS OFF"
)

function(cme_adapt_xz source binary)
  cme_alias(LibLZMA::LibLZMA liblzma)
  cme_export_variable(LibLZMA LIBLZMA_FOUND TRUE)
  cme_export_variable(LibLZMA LIBLZMA_LIBRARY LibLZMA::LibLZMA)
  cme_export_variable(LibLZMA LIBLZMA_LIBRARIES LibLZMA::LibLZMA)
  cme_export_variable(LibLZMA LIBLZMA_INCLUDE_DIR "${source}/src/liblzma/api")
  cme_export_variable(LibLZMA LIBLZMA_INCLUDE_DIRS "${source}/src/liblzma/api")
endfunction()
