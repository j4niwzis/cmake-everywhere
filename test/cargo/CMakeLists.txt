# A Rust library, built by cargo and linked into a C++ program.
#
#   cmake -S test/cargo -B build/cargo -G Ninja \
#     -DCMAKE_PROJECT_TOP_LEVEL_INCLUDES=$PWD/cmake-everywhere.cmake
#
# What it proves is the whole of the mechanism: cargo is run, what it built
# is read out of its own report rather than guessed at, what the Rust side
# needs from the system is asked of rustc, and the result links.
cmake_minimum_required(VERSION 3.24)
project(cme-cargo LANGUAGES CXX)

find_package(cme-greeting REQUIRED)

add_executable(cme-cargo main.cc)
target_link_libraries(cme-cargo PRIVATE cme::greeting)
target_compile_features(cme-cargo PRIVATE cxx_std_17)

cme_report()
