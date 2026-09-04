# The C++ runtime, from the same place the compiler comes from.
#
# A program that builds its own C library cannot then link the C++ runtime
# the machine has: that one was compiled against the machine's libc, by
# whichever compiler built it, and the optimiser cannot look inside it. The
# runtime that can be built here with this compiler is LLVM's -- libc++, the
# ABI library under it, and the unwinder under that.
#
# It brings one thing more, which matters to this project specifically:
# libc++ ships a manifest saying where the source of its std module is, so
# `import std` works without a build writing that file by hand, which is
# what every other build here does.
#
# Built into a prefix, because it is a toolchain rather than a library: what
# comes after it is compiled against it, and a compiler is handed a prefix
# and not a set of targets.
cme_declare_port(
  NAME llvm-runtimes
  PROVIDES llvm-runtimes libcxx
  VERSION 22.1.8
  LICENSE Apache-2.0-WITH-LLVM-exception
  CONFIGURE cmake
  # The same archive the compiler libraries come out of: the runtimes are a
  # directory in it. Nothing of LLVM itself is built for these -- they are
  # compiled by the compiler on this machine, not by one built here.
  SOURCE_FROM llvm-archive
  SOURCE_SUBDIR runtimes
  DEPENDS musl llvm-archive
  INSTALLED_TARGETS
    "lib/libc++.a=LLVM::cxx"
    "lib/libc++abi.a=LLVM::cxxabi"
    "lib/libunwind.a=LLVM::unwind"
  INSTALLED_INCLUDE include
  TARGETS LLVM::cxx
  CHECK_HEADER c++/v1/version
  OPTIONS
    "LLVM_ENABLE_RUNTIMES libcxx;libcxxabi;libunwind"
    # Archives, and the ABI library inside libc++ rather than beside it: a
    # program links one thing and gets all of it.
    "LIBCXX_ENABLE_SHARED OFF"
    "LIBCXX_ENABLE_STATIC ON"
    "LIBCXXABI_ENABLE_SHARED OFF"
    "LIBCXXABI_ENABLE_STATIC ON"
    "LIBUNWIND_ENABLE_SHARED OFF"
    "LIBUNWIND_ENABLE_STATIC ON"
    "LIBCXX_ENABLE_STATIC_ABI_LIBRARY ON"
    "LIBCXX_USE_COMPILER_RT ON"
    "LIBCXXABI_USE_COMPILER_RT ON"
    "LIBCXXABI_USE_LLVM_UNWINDER ON"
    # What `import std` is compiled from, and the manifest that says where.
    "LIBCXX_INSTALL_MODULES ON"
    # None of it runs here: no tests, no benchmarks, no documentation.
    "LIBCXX_INCLUDE_TESTS OFF"
    "LIBCXX_INCLUDE_BENCHMARKS OFF"
    "LIBCXX_INCLUDE_DOCS OFF"
    "LIBCXXABI_INCLUDE_TESTS OFF"
    "LIBUNWIND_INCLUDE_TESTS OFF"
    "CMAKE_BUILD_TYPE Release"
)
