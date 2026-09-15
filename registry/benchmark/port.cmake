# Missing upstream: nothing. google/benchmark ships CMake, exports
# benchmark::benchmark and benchmark::benchmark_main, and installs a
# benchmark.pc.
#
# The options are all about what it builds besides itself: its own tests want
# googletest, and a build that asked for a timing harness did not ask to fetch
# a testing framework to go with it.
cme_declare_port(
  NAME benchmark
  PROVIDES benchmark
  VERSION 1.9.4
  GITHUB_REPOSITORY google/benchmark
  GIT_TAG v1.9.4
  GIT_TAG_TEMPLATE "v@VERSION@"
  OPTIONS
    "BENCHMARK_ENABLE_TESTING OFF"
    "BENCHMARK_ENABLE_GTEST_TESTS OFF"
    "BENCHMARK_ENABLE_INSTALL OFF"
    # It builds with warnings as errors by default, which makes a new compiler
    # a broken dependency.
    "BENCHMARK_ENABLE_WERROR OFF"
  SYSTEM_PKGCONFIG "benchmark:benchmark::benchmark"
  LICENSE Apache-2.0
  LINK_NAMES
    "benchmark=benchmark::benchmark"
    "benchmark_main=benchmark::benchmark_main"
  TARGETS benchmark::benchmark benchmark::benchmark_main
  CHECK_HEADER benchmark/benchmark.h
)
