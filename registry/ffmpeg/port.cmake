# Missing upstream: a build system anything else can read. FFmpeg's configure
# is a shell script it wrote itself -- not autotools, not CMake, not meson --
# and what it produces is decided by four hundred options and a config.h it
# writes as it goes. There is nothing to import.
#
# So it is built its own way into a prefix, and the six libraries that come
# out are targets here. What a consumer gets is what it would get from a
# system FFmpeg, which is the point: the alternative is not having it.
cme_declare_port(
  NAME ffmpeg
  PROVIDES FFmpeg ffmpeg libav
  VERSION 7.1
  GIT_REPOSITORY https://git.ffmpeg.org/ffmpeg.git
  GIT_TAG n7.1
  GIT_TAG_TEMPLATE "n@VERSION@"
  LICENSE LGPL-2.1-or-later
  # Configured by its own script, because that is what writes config.h and
  # decides what this build of FFmpeg is -- and then its make is asked what
  # it would do rather than told to do it. Every source it names is compiled
  # in the consumer's graph, by the consumer's generator, with the flags
  # FFmpeg said to compile it with.
  CONFIGURE YES
  IMPORT make
  IMPORT_TARGETS
    "avcodec=FFmpeg::avcodec"
    "avformat=FFmpeg::avformat"
    "avutil=FFmpeg::avutil"
    "swscale=FFmpeg::swscale"
    "swresample=FFmpeg::swresample"
  SYSTEM_PKGCONFIG
    "libavcodec:FFmpeg::avcodec"
    "libavformat:FFmpeg::avformat"
    "libavutil:FFmpeg::avutil"
    "libswscale:FFmpeg::swscale"
    "libswresample:FFmpeg::swresample"
  LINK_NAMES
    "avcodec=FFmpeg::avcodec"
    "avformat=FFmpeg::avformat"
    "avutil=FFmpeg::avutil"
    "swscale=FFmpeg::swscale"
    "swresample=FFmpeg::swresample"
  TARGETS FFmpeg::avcodec FFmpeg::avformat FFmpeg::avutil FFmpeg::swscale
          FFmpeg::swresample
  CHECK_HEADER libavcodec/avcodec.h
  # Nothing but the libraries, and nothing in them that is not needed to
  # write a video file: no programs, no documentation, no network, no
  # decoders for formats a game does not read. Every one of these is a
  # smaller archive and one less thing that has to build.
  CONFIGURE_ARGS
    # Its configure reads no CC from the environment; it is told.
    "--cc=@CC@"
    "--cxx=@CXX@"
    # And no flags from the environment either -- it says so itself, and
    # what is in them is not decoration in a cross build: the target and the
    # sysroot are there, and without them its first test program does not
    # link and it reports a compiler that cannot make an executable.
    "--extra-cflags=@CFLAGS@"
    "--extra-cxxflags=@CXXFLAGS@"
    "--extra-ldflags=@LDFLAGS@"
    "--disable-shared"
    "--enable-static"
    "--enable-pic"
    "--disable-programs"
    "--disable-doc"
    "--disable-autodetect"
    "--disable-network"
    # Nothing but the five libraries themselves. Every codec, every
    # container and every parser is a feature: configure takes each
    # --enable-encoder it is given and adds to the set, so a build ends up
    # with the union of what everything in it asked for and nothing else.
    "--disable-everything"
    "--enable-avcodec"
    "--enable-avformat"
    "--enable-swscale"
    "--enable-swresample"
    "--enable-protocol=file"
  CONFIGURE_CROSS
    "--enable-cross-compile"
    "--cross-prefix=@CROSS_PREFIX@"
    "--arch=@TARGET_CPU@"
    "--target-os=@TARGET_OS_LOWER@"
    # The tools that belong to that compiler rather than to this machine: a
    # host ar will put another architecture's objects in an archive and a
    # host strip will not read one.
    "--ar=@AR@"
    "--ranlib=@RANLIB@"
    # It builds and runs programs of its own to write tables, and those run
    # here rather than there.
    "--host-cc=@BUILD_MACHINE_CC@"
    "--nm=@NM@"
    "--strip=@STRIP@"
)

# What can be written without anything else being installed, and what a
# file written that way is put in. Off, like everything else here: five
# libraries that read and write nothing is exactly what a build that named
# no codec asked for, and a consumer that names three gets three.
cme_port_feature(ffmpeg mpeg4
  SUMMARY "MPEG-4 part 2, which needs nothing installed to encode"
  CONFIGURE_ARGS "--enable-encoder=mpeg4" "--enable-decoder=mpeg4"
                 "--enable-parser=mpeg4video")
cme_port_feature(ffmpeg rawvideo
  SUMMARY "uncompressed frames"
  CONFIGURE_ARGS "--enable-encoder=rawvideo" "--enable-decoder=rawvideo")
cme_port_feature(ffmpeg png
  SUMMARY "PNG, a frame at a time"
  CONFIGURE_ARGS "--enable-encoder=png" "--enable-decoder=png")
cme_port_feature(ffmpeg mp4
  SUMMARY "the MP4 and QuickTime container"
  CONFIGURE_ARGS "--enable-muxer=mp4,mov" "--enable-demuxer=mov")

# Containers, each one a muxer and the demuxer that reads it back.
cme_port_feature(ffmpeg matroska
  SUMMARY "the Matroska and WebM container"
  CONFIGURE_ARGS "--enable-muxer=matroska,webm" "--enable-demuxer=matroska")
cme_port_feature(ffmpeg avi
  SUMMARY "the AVI container"
  CONFIGURE_ARGS "--enable-muxer=avi" "--enable-demuxer=avi")
cme_port_feature(ffmpeg image2
  SUMMARY "a numbered file per frame"
  CONFIGURE_ARGS "--enable-muxer=image2" "--enable-demuxer=image2")

# Video, read. A background video in a game is one of these, and which one
# is decided by whoever made it.
cme_port_feature(ffmpeg h264
  SUMMARY "H.264, decoded"
  CONFIGURE_ARGS "--enable-decoder=h264" "--enable-parser=h264")
cme_port_feature(ffmpeg hevc
  SUMMARY "H.265, decoded"
  CONFIGURE_ARGS "--enable-decoder=hevc" "--enable-parser=hevc")
cme_port_feature(ffmpeg vp9
  SUMMARY "VP9, decoded"
  CONFIGURE_ARGS "--enable-decoder=vp9" "--enable-parser=vp9")
cme_port_feature(ffmpeg theora
  SUMMARY "Theora, decoded"
  CONFIGURE_ARGS "--enable-decoder=theora" "--enable-parser=vp3")

# Audio, read.
cme_port_feature(ffmpeg aac
  SUMMARY "AAC, decoded"
  CONFIGURE_ARGS "--enable-decoder=aac" "--enable-parser=aac"
                 "--enable-demuxer=aac")
cme_port_feature(ffmpeg mp3
  SUMMARY "MP3, decoded"
  CONFIGURE_ARGS "--enable-decoder=mp3" "--enable-parser=mpegaudio"
                 "--enable-demuxer=mp3")
cme_port_feature(ffmpeg vorbis
  SUMMARY "Vorbis, decoded"
  CONFIGURE_ARGS "--enable-decoder=vorbis" "--enable-parser=vorbis"
                 "--enable-demuxer=ogg")
cme_port_feature(ffmpeg opus
  SUMMARY "Opus, decoded"
  CONFIGURE_ARGS "--enable-decoder=opus" "--enable-parser=opus"
                 "--enable-demuxer=ogg")

# x264 is the encoder anything watching wants, and it is GPL: linking it
# makes the result GPL. Off unless asked for, which is a licence saying so
# and not a guess about what a build wants.
#
# It comes from the port beside this one rather than from the machine, so
# there is nothing to install and a phone gets the same encoder a desktop
# does. FFmpeg looks for it the only way its configure knows -- pkg-config,
# or a header and a library on the compiler's own paths -- and a library
# this build has just built is on neither, so it is told where.
cme_port_feature(ffmpeg x264
  SUMMARY "H.264 through libx264, which is GPL"
  DEPENDS x264
  CONFIGURE_ARGS "--enable-libx264" "--enable-gpl"
                 "--enable-encoder=libx264,libx264rgb"
                 "--extra-cflags=@DEPENDS_CFLAGS@"
                 "--extra-ldflags=@DEPENDS_LDFLAGS@")

function(cme_adapt_ffmpeg source binary)
  # Where its headers are, for whoever links it. Every source it compiles
  # was given these as private flags by its own build; a consumer writes
  # <libavcodec/avcodec.h> and has been given nothing at all.
  #
  # Two directories, because FFmpeg's configure builds out of tree and puts
  # what it generated -- config.h, and the tables it writes -- beside the
  # objects, with a symlink called src pointing back at the checkout.
  set(built "${CMAKE_BINARY_DIR}/_cme/ffmpeg-build")
  foreach(name avcodec avformat avutil swscale swresample)
    if(TARGET ffmpeg_${name})
      target_include_directories(ffmpeg_${name} INTERFACE
        "$<BUILD_INTERFACE:${source}>" "$<BUILD_INTERFACE:${built}>")
    endif()
  endforeach()
  cme_export_variable(FFmpeg FFMPEG_FOUND TRUE)
  cme_export_variable(FFmpeg FFMPEG_INCLUDE_DIRS "${source};${built}")
  cme_export_variable(FFmpeg FFMPEG_LIBRARIES
                      "FFmpeg::avcodec;FFmpeg::avformat;FFmpeg::avutil;FFmpeg::swscale;FFmpeg::swresample")
endfunction()
