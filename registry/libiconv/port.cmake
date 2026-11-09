# Android before API 28 has no iconv in libc. Build GNU libiconv rather than
# silently using headers or libraries from the machine doing the build.
cme_declare_port(
  NAME libiconv
  PROVIDES LibIconv libiconv iconv
  VERSION 1.18
  # From kernel.org's GNU mirror: ftp.gnu.org itself refused mux's Android
  # build six times in a row. The digest below is the archive's either way.
  URL "https://mirrors.kernel.org/gnu/libiconv/libiconv-1.18.tar.gz"
  URL_HASH "SHA256=3b08f5f4f9b4eb82f151a7040bfd6fe6c6fb922efe4b1659c66ea933276965e8"
  LICENSE LGPL-2.1-or-later
  # The command-line utility's gnulib error support uses Android API 23
  # globals. GLib only needs the library; do not build or install the CLI.
  PATCHES "patches/0001-build-libraries-only.patch"
  # Its configure at the configure stage (iconv.h is written there), its
  # make read and its library compiled here.
  CONFIGURE YES
  IMPORT make
  IMPORT_TARGETS "iconv=Iconv::Iconv"
  SYSTEM_PKGCONFIG "libiconv:Iconv::Iconv"
  LINK_NAMES "iconv=Iconv::Iconv"
  TARGETS Iconv::Iconv
  CHECK_HEADER iconv.h
  CONFIGURE_ARGS "--disable-shared" "--enable-static" "--disable-nls" "--with-pic"
  CONFIGURE_CROSS "--host=@TRIPLE@"
)

function(cme_adapt_libiconv source binary)
  # iconv.h, as its configure wrote it for this machine.
  if(TARGET libiconv_iconv)
    target_include_directories(libiconv_iconv INTERFACE
      "$<BUILD_INTERFACE:${CMAKE_BINARY_DIR}/_cme/libiconv-build/include>")
  endif()
endfunction()
