# A program the build that uses it runs, rather than links.
cmake_minimum_required(VERSION 3.24)
project(cme-stamp LANGUAGES CXX)
add_executable(cme-stamp main.cc)
target_compile_features(cme-stamp PRIVATE cxx_std_17)
