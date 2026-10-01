# vodozemac through the kazv project's C++ bindings: a Rust staticlib with a
# cxx bridge, built by the cargo import, its bridge compiled by this build's
# compiler -- clang with libc++ in CI, as a program built that way links it.
#
#   cmake -S test/vodozemac -B build/vodozemac -G Ninja \
#     -DCMAKE_PROJECT_TOP_LEVEL_INCLUDES=$PWD/cmake-everywhere.cmake
#
# What it proves: the checkout prepared (its lib.rs written by its own
# script), cargo run, the bridge's headers found, and Megolm round trips
# from C++.
cmake_minimum_required(VERSION 3.24)
project(cme-vodozemac LANGUAGES C CXX)

find_package(vodozemac REQUIRED)

add_executable(cme-vodozemac main.cc)
target_link_libraries(cme-vodozemac PRIVATE vodozemac::vodozemac)
target_compile_features(cme-vodozemac PRIVATE cxx_std_20)

cme_report()
