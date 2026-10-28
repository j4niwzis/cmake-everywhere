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
  CONFIGURE YES
  CONFIGURE_INSTALL install-lib
  INSTALLED_TARGETS "lib/libiconv.a=Iconv::Iconv"
  INSTALLED_INCLUDE include
  SYSTEM_PKGCONFIG "libiconv:Iconv::Iconv"
  LINK_NAMES "iconv=Iconv::Iconv"
  TARGETS Iconv::Iconv
  CHECK_HEADER iconv.h
  CONFIGURE_ARGS "--disable-shared" "--enable-static" "--disable-nls" "--with-pic"
  CONFIGURE_CROSS "--host=@TRIPLE@"
)
