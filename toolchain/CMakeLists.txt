# The toolchain a self-contained build is compiled against.
#
# Everything else in such a build is compiled against a C library and a C++
# runtime, so both have to exist before anything else is configured -- and a
# compiler is chosen when project() runs, before a single port has been
# fetched. That is why this is a build of its own: it makes the toolchain,
# and the build that uses it is configured afterwards, pointed at what this
# installed.
#
#   cmake -S <cme>/toolchain -B build/toolchain
#   cmake --build build/toolchain
#   cmake -S . -B build --toolchain build/toolchain/cme-toolchain.cmake
#
# What it produces is a prefix and a toolchain file naming it.
#
# The provider is used for what it is good at here and no more: it fetches
# the sources, holds them to their pins and writes them into the lock. The
# building is a graph -- one target per thing, with the dependencies between
# them said outright -- because that is what a build system is for: it runs
# in parallel, it rebuilds what changed, and it says what it is doing while
# it does it. Doing that work while configuring is a long silence and a
# rebuild from nothing every time.
cmake_minimum_required(VERSION 3.28 FATAL_ERROR)

set(CMAKE_PROJECT_TOP_LEVEL_INCLUDES
    "${CMAKE_CURRENT_LIST_DIR}/../cmake-everywhere.cmake"
    CACHE STRING "")

# Fetched and not built: this project builds them itself, below.
set(CME_FETCH_ONLY ON CACHE BOOL "" FORCE)

project(cme-toolchain LANGUAGES C)

include(ExternalProject)
include(ProcessorCount)
ProcessorCount(cme_cores)
if(cme_cores EQUAL 0)
  set(cme_cores 1)
endif()

set(CME_TOOLCHAIN_PREFIX "${CMAKE_BINARY_DIR}/prefix" CACHE PATH
    "Where the C library and the C++ runtime are installed")

# What each of them is, by the pins the registry carries.
find_package(musl QUIET)
find_package(kernel-headers QUIET)
find_package(llvm_archive QUIET)

foreach(port musl kernel-headers llvm-archive)
  get_property(cme_${port}_tree GLOBAL PROPERTY CME_TREE_${port})
  if(NOT cme_${port}_tree)
    message(FATAL_ERROR
      "cmake-everywhere: ${port} was not fetched, so there is nothing to "
      "build a toolchain out of")
  endif()
endforeach()

# And that what was fetched is the tree and not the shape of one.
#
# A build directory pointed into the source cache leaves the directory it
# was pointed at, whether or not anything unpacked there -- and a cache with
# an empty directory in it looks fetched to whatever asks next. So what has
# to be inside is named here, once, where the answer is still cheap.
if(NOT EXISTS "${cme_llvm-archive_tree}/runtimes/CMakeLists.txt")
  message(FATAL_ERROR
    "cmake-everywhere: ${cme_llvm-archive_tree} has no runtimes in it. If it "
    "is empty, something claimed that directory before the archive was "
    "unpacked: remove it and configure again.")
endif()

# The C library.
#
# Its configure script is its own rather than autotools, and what it
# produces is the prefix everything after it is compiled against.
ExternalProject_Add(cme_musl
  SOURCE_DIR "${cme_musl_tree}"
  CONFIGURE_COMMAND "${cme_musl_tree}/configure"
                    "--prefix=${CME_TOOLCHAIN_PREFIX}"
                    "--disable-shared" "--enable-static"
                    "CC=${CMAKE_C_COMPILER}"
  BUILD_COMMAND make "-j${cme_cores}"
  INSTALL_COMMAND make install
  BUILD_IN_SOURCE OFF
  USES_TERMINAL_BUILD YES
  LOG_CONFIGURE NO LOG_BUILD NO LOG_INSTALL NO)

# The kernel's headers, beside the C library's.
#
# A program includes both without knowing the difference -- linux/limits.h
# and stdio.h are one include path to it -- so they go into the same prefix.
# Two directories: what every architecture shares, and what this one adds.
set(cme_arch "${CMAKE_SYSTEM_PROCESSOR}")
if(cme_arch STREQUAL "" OR cme_arch STREQUAL "AMD64")
  set(cme_arch "x86_64")
elseif(cme_arch STREQUAL "arm64")
  set(cme_arch "aarch64")
endif()
if(NOT IS_DIRECTORY "${cme_kernel-headers_tree}/${cme_arch}/include")
  message(FATAL_ERROR
    "cmake-everywhere: the kernel headers carry nothing for ${cme_arch}, and "
    "a program built for it includes them")
endif()

add_custom_command(
  OUTPUT "${CME_TOOLCHAIN_PREFIX}/include/linux/limits.h"
  COMMAND ${CMAKE_COMMAND} -E copy_directory
          "${cme_kernel-headers_tree}/generic/include"
          "${CME_TOOLCHAIN_PREFIX}/include"
  COMMAND ${CMAKE_COMMAND} -E copy_directory
          "${cme_kernel-headers_tree}/${cme_arch}/include"
          "${CME_TOOLCHAIN_PREFIX}/include"
  DEPENDS cme_musl
  COMMENT "cmake-everywhere: the kernel's headers, beside the C library's"
  VERBATIM)

# The archive a distribution's compiler links by name.
#
# Alpine builds its clang to pass -lssp_nonshared on every link: that is
# where its C library keeps the one function the stack protector calls, and
# a compiler configured for that library asks for it whether or not the
# library in use has it. musl defines that function in libc itself, so what
# is missing is not the code but the name -- an archive with nothing in it
# is the whole of what is needed.
find_program(CME_TOOLCHAIN_AR NAMES llvm-ar ar REQUIRED)
add_custom_command(
  OUTPUT "${CME_TOOLCHAIN_PREFIX}/lib/libssp_nonshared.a"
  COMMAND "${CME_TOOLCHAIN_AR}" rcs
          "${CME_TOOLCHAIN_PREFIX}/lib/libssp_nonshared.a"
  DEPENDS cme_musl
  COMMENT "cmake-everywhere: the name a distribution's compiler links"
  VERBATIM)

add_custom_target(cme_libc ALL
  DEPENDS "${CME_TOOLCHAIN_PREFIX}/include/linux/limits.h"
          "${CME_TOOLCHAIN_PREFIX}/lib/libssp_nonshared.a")

# The C++ runtime, compiled against that C library.
#
# LLVM's, because a program that builds its own C library cannot link the
# runtime the machine has: that one was compiled against the machine's libc,
# by whichever compiler built it. It also ships the manifest that says where
# the source of its std module is, which is what `import std` compiles from.
set(cme_runtime_flags
    "--sysroot=${CME_TOOLCHAIN_PREFIX} -nostdinc -isystem ${CME_TOOLCHAIN_PREFIX}/include")
ExternalProject_Add(cme_runtimes
  SOURCE_DIR "${cme_llvm-archive_tree}/runtimes"
  DEPENDS cme_libc
  CMAKE_ARGS
    "-DCMAKE_INSTALL_PREFIX=${CME_TOOLCHAIN_PREFIX}"
    "-DCMAKE_BUILD_TYPE=Release"
    "-DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}"
    "-DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}"
    "-DCMAKE_C_FLAGS=${cme_runtime_flags}"
    "-DCMAKE_CXX_FLAGS=${cme_runtime_flags}"
    "-DCMAKE_EXE_LINKER_FLAGS=--sysroot=${CME_TOOLCHAIN_PREFIX} -fuse-ld=lld -rtlib=compiler-rt -static"
    "-DLLVM_ENABLE_RUNTIMES=libcxx;libcxxabi;libunwind"
    "-DLIBCXX_ENABLE_SHARED=OFF"
    "-DLIBCXX_ENABLE_STATIC=ON"
    "-DLIBCXXABI_ENABLE_SHARED=OFF"
    "-DLIBCXXABI_ENABLE_STATIC=ON"
    "-DLIBUNWIND_ENABLE_SHARED=OFF"
    "-DLIBUNWIND_ENABLE_STATIC=ON"
    "-DLIBCXX_ENABLE_STATIC_ABI_LIBRARY=ON"
    "-DLIBCXX_CXX_ABI=libcxxabi"
    "-DLIBCXX_HAS_MUSL_LIBC=ON"
    "-DLIBCXX_USE_COMPILER_RT=ON"
    "-DLIBCXXABI_USE_COMPILER_RT=ON"
    "-DLIBCXXABI_USE_LLVM_UNWINDER=ON"
    "-DLIBCXX_INSTALL_MODULES=ON"
    "-DLIBCXX_INCLUDE_TESTS=OFF"
    "-DLIBCXX_INCLUDE_BENCHMARKS=OFF"
    "-DLIBCXX_INCLUDE_DOCS=OFF"
    "-DLIBCXXABI_INCLUDE_TESTS=OFF"
    "-DLIBUNWIND_INCLUDE_TESTS=OFF"
  USES_TERMINAL_BUILD YES
  LOG_CONFIGURE NO LOG_BUILD NO LOG_INSTALL NO)

# And the file that says where all of it is.
#
# Everything after this is compiled with these headers and linked against
# these archives, and against nothing on the machine: -nostdinc and -static
# say so outright, so that a header or a library that was not named here is
# a build that stops rather than a program with two C libraries in it.
#
# -rtlib is said where linking happens and not where compiling does: a
# compiler handed it while only compiling warns that nothing used it, which
# is an error under -Werror -- and a build system that tests flags that way
# then concludes the compiler supports nothing at all.
set(cme_toolchain_file "${CMAKE_BINARY_DIR}/cme-toolchain.cmake")
file(GENERATE OUTPUT "${cme_toolchain_file}" CONTENT
"# Written by cmake-everywhere's toolchain build.
set(CMAKE_SYSROOT \"${CME_TOOLCHAIN_PREFIX}\")
set(CME_TOOLCHAIN_PREFIX \"${CME_TOOLCHAIN_PREFIX}\")

set(CMAKE_C_FLAGS_INIT
    \"--sysroot=${CME_TOOLCHAIN_PREFIX} -nostdinc -isystem ${CME_TOOLCHAIN_PREFIX}/include\")
set(CMAKE_CXX_FLAGS_INIT
    \"--sysroot=${CME_TOOLCHAIN_PREFIX} -nostdinc -isystem ${CME_TOOLCHAIN_PREFIX}/include/c++/v1 -isystem ${CME_TOOLCHAIN_PREFIX}/include -stdlib=libc++\")
set(CMAKE_EXE_LINKER_FLAGS_INIT
    \"--sysroot=${CME_TOOLCHAIN_PREFIX} -static -fuse-ld=lld -rtlib=compiler-rt --unwindlib=libunwind -nostdlib++ -L${CME_TOOLCHAIN_PREFIX}/lib\")
set(CMAKE_CXX_STANDARD_LIBRARIES \"-lc++ -lc++abi -lunwind\")
")

message(STATUS
  "cmake-everywhere: build this, and the toolchain is ${cme_toolchain_file}")
