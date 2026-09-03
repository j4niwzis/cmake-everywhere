# What a consumer looks like. One find_package, one target linked, and the
# four libraries libsndfile reads are resolved on the way.
#
#   cmake -S test -B build/test -G Ninja
#   cmake --build build/test
#
# Add -DCME_SYSTEM=NEVER to prove the ports build without anything installed,
# or -DCME_SYSTEM=ALWAYS to prove the system copies are used when they exist.

cmake_minimum_required(VERSION 3.24)
project(cme-test LANGUAGES C)

find_package(SndFile REQUIRED)
find_package(PNG REQUIRED)
find_package(minimp3 REQUIRED)

add_executable(cme-test main.c)
target_link_libraries(cme-test PRIVATE
  SndFile::sndfile PNG::PNG minimp3::minimp3)
