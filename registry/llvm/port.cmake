# The compiler Mesa carries inside itself.
#
# Two of its drivers translate shaders with LLVM rather than with a backend
# of their own: radeonsi compiles for AMD's instruction set, and llvmpipe
# compiles for this machine's, which is what makes a software rasteriser
# fast enough to be worth having. Every other driver here -- RADV, ANV,
# Turnip, NVK -- brings its own compiler and does not want this one.
#
# Built into a prefix rather than into the consumer's graph. LLVM is
# thousands of targets, and what asks for it does not want targets: Mesa
# runs llvm-config and links what that program names.
#
# Only the targets a build can use. LLVM builds every architecture it knows
# by default, which is an hour of a machine spent on instruction sets no
# driver here will ever emit: the host, because llvmpipe compiles for the
# machine it runs on, and AMDGPU, because radeonsi compiles for the card.
cme_declare_port(
  NAME llvm
  PROVIDES LLVM llvm
  VERSION 22.1.8
  # Out of the archive beside this, which the runtime port is built out of
  # too: one download of a monorepo, and two directories in it.
  SOURCE_FROM llvm-archive
  # Apache 2.0 with the LLVM exception, which is what lets a program that
  # links it stay under its own licence.
  LICENSE Apache-2.0-WITH-LLVM-exception
  CONFIGURE cmake
  SOURCE_SUBDIR llvm
  DEPENDS llvm-archive
  INSTALLED_TARGETS ""
  INSTALLED_INCLUDE include
  PROGRAMS "bin/llvm-config=LLVM::config"
  SYSTEM_PKGCONFIG "llvm"
  CHECK_HEADER llvm-c/Core.h
  OPTIONS
    "LLVM_TARGETS_TO_BUILD Native\;AMDGPU"
    "LLVM_BUILD_LLVM_DYLIB OFF"
    "LLVM_LINK_LLVM_DYLIB OFF"
    "LLVM_ENABLE_PIC ON"
    "LLVM_ENABLE_TERMINFO OFF"
    "LLVM_ENABLE_LIBXML2 OFF"
    "LLVM_ENABLE_ZSTD OFF"
    "LLVM_ENABLE_ZLIB OFF"
    "LLVM_ENABLE_LIBEDIT OFF"
    "LLVM_ENABLE_LIBPFM OFF"
    "LLVM_ENABLE_BINDINGS OFF"
    "LLVM_INCLUDE_TESTS OFF"
    "LLVM_INCLUDE_BENCHMARKS OFF"
    "LLVM_INCLUDE_EXAMPLES OFF"
    "LLVM_INCLUDE_DOCS OFF"
    "LLVM_INCLUDE_UTILS OFF"
    "LLVM_BUILD_TOOLS OFF"
    "LLVM_ENABLE_ASSERTIONS OFF"
    "CMAKE_BUILD_TYPE Release"
)
