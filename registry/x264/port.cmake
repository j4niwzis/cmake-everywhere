# Missing upstream: a build system anything else can read. x264 has a
# configure script of its own -- not autotools, not CMake -- and a Makefile
# it writes as it goes, so there is nothing to import until it has run.
#
# The same shape as the ffmpeg port beside it, and for the same reason: the
# script is run, and then its make is asked what it would do rather than
# told to do it. Every source it names is compiled in the consumer's graph.
# What its configure has to be told when the compiler is emscripten.
#
# It reads the machine out of the triple it is given, and wasm32 is not a
# machine it knows: told one, it writes a config for the machine it is
# running on and the build assembles x86 into a wasm object. A generic
# 32-bit host with no assembly is what there is, and saying that is what
# every other project that builds it this way says. The sysroot is
# emscripten's own and it knows where that is.
set(cme_x264_machine
    "--host=@TRIPLE@"
    "--cross-prefix=@CROSS_PREFIX@"
    "--sysroot=@SYSROOT@")
if(CMAKE_SYSTEM_NAME STREQUAL "Emscripten")
  set(cme_x264_machine "--host=i686-gnu" "--disable-asm")
endif()

cme_declare_port(
  NAME x264
  PROVIDES x264 X264
  VERSION 164
  GIT_REPOSITORY https://code.videolan.org/videolan/x264.git
  GIT_TAG b35605ace3ddf7c1a5d67a2eb553f034aef41d55
  # GPL, and that is the whole of why it is not fetched by default: a
  # program that links it is a program under the GPL. Whoever asks for it
  # has said so.
  LICENSE GPL-2.0-or-later
  # Built its own way into a prefix, rather than read and compiled here.
  #
  # What asks for x264 is FFmpeg, and FFmpeg asks for it through
  # pkg-config -- that is the only way its configure knows. A pkg-config
  # file describes an install: a prefix with headers under include and the
  # archive under lib. So this port produces one, which is the shape the
  # thing that wants it can use.
  CONFIGURE YES
  INSTALLED_TARGETS "lib/libx264.a=x264::x264"
  INSTALLED_INCLUDE include
  SYSTEM_PKGCONFIG "x264:x264::x264"
  LINK_NAMES "x264=x264::x264"
  TARGETS x264::x264
  # In this order, because x264.h says so and does not do it itself: "You
  # must include stdint.h before x264.h."
  CHECK_HEADER stdint.h x264.h
  # On x86 it assembles its own code and says so if it cannot: "Found no
  # assembler. Minimum version is nasm-2.13." On aarch64 the assembly is
  # .S files, which the compiler takes.
  CONFIGURE_ARGS
    # The flags this build compiles with, for the two of its three
    # questions that are asked with them. The assembler's are their own:
    # where the assembly is .S the assembler is the C compiler and needs the
    # target, or its NEON check assembles for this machine and the answer is
    # "no NEON support, try adding -mfpu=neon" -- advice about a question
    # asked wrong; where the assembly is .asm the assembler is nasm, which
    # takes none of a compiler's flags.
    "--extra-cflags=@CFLAGS@"
    "--extra-asflags=@ASFLAGS@"
    "--extra-ldflags=@LDFLAGS@"
    # An encoder to link, not a program to run.
    "--enable-static"
    "--enable-pic"
    "--disable-cli"
    # What it would otherwise look for on the machine and link if it found
    # it: this port builds an encoder and nothing that reads a file.
    "--disable-avs"
    "--disable-swscale"
    "--disable-lavf"
    "--disable-ffms"
    "--disable-gpac"
    "--disable-lsmash"
    # A compiler that runs elsewhere cannot be asked to run its own output,
    # and that is what this check does.
    "--disable-opencl"
  CONFIGURE_CROSS
    ${cme_x264_machine}
)

function(cme_adapt_x264 source binary)
  cme_export_variable(x264 X264_FOUND TRUE)
  cme_export_variable(x264 X264_LIBRARY x264::x264)
  cme_export_variable(x264 X264_LIBRARIES x264::x264)
  if(CME_INSTALLED_x264)
    cme_export_variable(x264 X264_INCLUDE_DIRS "${CME_INSTALLED_x264}/include")
  endif()
endfunction()
