#include <cstdio>

// Deliberately empty of the library being checked. Including its headers
// would test the header; linking its target tests the port.
int main() {
  std::printf("linked\n");
  return 0;
}
