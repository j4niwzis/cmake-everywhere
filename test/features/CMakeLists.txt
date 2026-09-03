# Feature resolution on real libraries, without the expensive one.
#
# freetype is asked for with colour bitmap glyphs, which is a feature that
# brings libpng, which brings zlib. flac is asked for plainly and gets its
# Ogg support anyway, because its port has that on unless refused -- the same
# as libFLAC's own build. The report at the end says all of it.

cmake_minimum_required(VERSION 3.24)
project(cme-features LANGUAGES C)

find_package(Freetype REQUIRED COMPONENTS png)
find_package(FLAC REQUIRED)

add_executable(cme-features main.c)
target_link_libraries(cme-features PRIVATE Freetype::Freetype FLAC::FLAC)

cme_report()
