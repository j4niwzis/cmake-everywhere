# The toolchain a self-contained build is compiled against.
#
# Everything else in such a build is compiled against a C library and a C++
# runtime, which means both have to exist before anything else is
# configured -- and a compiler is chosen when a project() runs, before a
# single port has been fetched. That is the whole reason this is a separate
# build: it makes the toolchain, and the build that uses it is configured
# afterwards, pointed at what this installed.
#
# Two commands rather than one, and honest about it:
#
#   cmake -S <cme>/toolchain -B build/toolchain -DCME_TOOLCHAIN_PREFIX=...
#   cmake --build build/toolchain
#   cmake -S . -B build --toolchain build/toolchain/cme-toolchain.cmake
#
# What it produces is a prefix and a toolchain file naming it.
cmake_minimum_required(VERSION 3.28 FATAL_ERROR)

set(CMAKE_PROJECT_TOP_LEVEL_INCLUDES
    "${CMAKE_CURRENT_LIST_DIR}/../cmake-everywhere.cmake"
    CACHE STRING "")

project(cme-toolchain LANGUAGES C)

set(CME_TOOLCHAIN_PREFIX "${CMAKE_BINARY_DIR}/prefix" CACHE PATH
    "Where the C library and the C++ runtime are installed")

# The C library first: the runtime below is compiled against it.
find_package(musl REQUIRED)
find_package(kernel-headers REQUIRED)
find_package(llvm-runtimes REQUIRED)

# And the file that says where all of it is.
#
# Everything after this is compiled with these headers and linked against
# these archives, and against nothing on the machine: -nostdinc and
# -nostdlib say so outright, so that a header or a library that was not
# named here is a build that stops rather than a program that mixes two C
# libraries.
get_property(musl_prefix GLOBAL PROPERTY CME_INSTALLED_musl)
get_property(runtime_prefix GLOBAL PROPERTY CME_INSTALLED_llvm-runtimes)
if(NOT musl_prefix)
  set(musl_prefix "${CME_INSTALLED_musl}")
endif()
if(NOT runtime_prefix)
  set(runtime_prefix "${CME_INSTALLED_llvm-runtimes}")
endif()

# The kernel's headers, beside the C library's.
#
# A program includes both without knowing the difference -- linux/limits.h
# and stdio.h are one include path to it -- so they are installed into the
# same prefix. Two directories: what every architecture shares, and what
# this one adds.
set(cme_arch "${CMAKE_SYSTEM_PROCESSOR}")
if(cme_arch STREQUAL "" OR cme_arch STREQUAL "AMD64")
  set(cme_arch "x86_64")
endif()
if(cme_arch STREQUAL "arm64")
  set(cme_arch "aarch64")
endif()
if(NOT EXISTS "${musl_prefix}/include/linux/limits.h")
  file(COPY "${KERNEL_HEADERS_DIR}/generic/include/"
       DESTINATION "${musl_prefix}/include")
  if(IS_DIRECTORY "${KERNEL_HEADERS_DIR}/${cme_arch}/include")
    file(COPY "${KERNEL_HEADERS_DIR}/${cme_arch}/include/"
         DESTINATION "${musl_prefix}/include")
  else()
    message(FATAL_ERROR
      "cmake-everywhere: the kernel headers carry nothing for ${cme_arch}, "
      "and a program built for it includes them")
  endif()
endif()

# The archive a distribution's compiler links by name.
#
# Alpine builds its clang to pass -lssp_nonshared on every link: that is
# where its C library keeps the one function the stack protector calls, and
# a compiler configured for that library asks for it whether or not the
# library in use has it. musl defines that function in libc itself, so what
# is missing is not the code but the name -- an archive with nothing in it
# is the whole of what is needed, and a link that asks for it finds it.
find_program(CME_TOOLCHAIN_AR NAMES llvm-ar ar REQUIRED)
if(NOT EXISTS "${musl_prefix}/lib/libssp_nonshared.a")
  execute_process(COMMAND "${CME_TOOLCHAIN_AR}" rcs
                          "${musl_prefix}/lib/libssp_nonshared.a"
                  RESULT_VARIABLE made)
  if(NOT made EQUAL 0)
    message(WARNING
      "cmake-everywhere: could not write libssp_nonshared.a, and a compiler "
      "that links it by name will not find it")
  endif()
endif()

file(WRITE "${CMAKE_BINARY_DIR}/cme-toolchain.cmake"
"# Written by cmake-everywhere's toolchain build.
#
# The C library and the C++ runtime this build compiles against, both built
# by that build from pinned sources. Nothing from the machine: a header or an
# archive that is not in one of these prefixes is not there at all.
set(CMAKE_SYSROOT \"${musl_prefix}\")
set(CME_TOOLCHAIN_MUSL \"${musl_prefix}\")
set(CME_TOOLCHAIN_RUNTIME \"${runtime_prefix}\")

# The compiler's own runtime is LLVM's, not GCC's: this build has no libgcc
# in it and wants none -- the unwinder, the builtins and the C++ ABI all come
# from the same place the compiler does.
#
# Said where linking happens and not where compiling does. -rtlib is a flag
# about the link, and a compiler handed it while only compiling warns that
# nothing used it -- which is an error under -Werror, and a build system
# that tests flags by compiling with -Werror then concludes the compiler
# supports nothing at all.
set(CMAKE_C_FLAGS_INIT
    \"--sysroot=${musl_prefix} -nostdinc -isystem ${musl_prefix}/include\")
set(CMAKE_CXX_FLAGS_INIT
    \"--sysroot=${musl_prefix} -nostdinc -isystem ${runtime_prefix}/include/c++/v1 -isystem ${musl_prefix}/include -stdlib=libc++\")
set(CMAKE_EXE_LINKER_FLAGS_INIT
    \"--sysroot=${musl_prefix} -static -fuse-ld=lld -rtlib=compiler-rt --unwindlib=libunwind -nostdlib++ -L${runtime_prefix}/lib -L${musl_prefix}/lib\")
set(CMAKE_CXX_STANDARD_LIBRARIES \"-lc++ -lc++abi -lunwind\")
")
message(STATUS
  "cmake-everywhere: the toolchain is in ${CMAKE_BINARY_DIR}/cme-toolchain.cmake")
