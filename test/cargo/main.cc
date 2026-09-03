// The Rust side says its version; this side checks that it is the version
// the port pinned. Linking alone would prove only that some symbol was
// found somewhere.
#include <cstdio>
#include <cstring>

extern "C" const char *cme_greeting();

int main() {
  const char *said = cme_greeting();
  const char *wanted = "cme-greeting 0.1.0";
  if (said == nullptr || std::strcmp(said, wanted) != 0) {
    std::printf("rust said %s, and this build asked for %s\n",
                said == nullptr ? "nothing" : said, wanted);
    return 1;
  }
  std::printf("%s, linked from Rust\n", said);
  return 0;
}
