#!/bin/sh
# The test consumer, configured the way a real project would be.
set -e
here=$(cd "$(dirname "$0")" && pwd)
cmake -S "$here" -B "${1:-$here/../build/test}" -G Ninja \
  -DCMAKE_PROJECT_TOP_LEVEL_INCLUDES="$here/../cmake-everywhere.cmake" \
  "${@:2}"
cmake --build "${1:-$here/../build/test}"
