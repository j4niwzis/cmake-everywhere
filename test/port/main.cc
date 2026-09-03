#include <cstdio>

// Linking the target is what says the port produces a library. Including its
// header is what says the library can be used, and the two fail differently:
// a target whose include directories are private links and does not compile.
// So when a port names a header, this file is not the one that is built --
// see CMakeLists.txt.
int main() {
  std::printf("linked\n");
  return 0;
}
