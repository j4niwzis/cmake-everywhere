// Writes what it was told to write, which is enough to prove it ran.
#include <fstream>
int main(int count, char **arguments) {
  if (count < 2) {
    return 2;
  }
  std::ofstream out(arguments[1]);
  out << "written by a program this build built for itself\n";
  return out ? 0 : 1;
}
