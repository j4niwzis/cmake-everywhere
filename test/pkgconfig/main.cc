#include <cstdio>
#include <zlib.h>

int main() {
  std::printf("zlib %s through pkg-config\n", zlibVersion());
  return 0;
}
