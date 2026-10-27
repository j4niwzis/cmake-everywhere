#include <iconv.h>
#include <string.h>

int main(void) {
  iconv_t convert = iconv_open("UTF-8", "ISO-8859-1");
  if (convert == (iconv_t)-1) return 1;
  char input[] = { (char)0xe9 };
  char output[8] = {0};
  char *from = input, *to = output;
  size_t left = sizeof input, room = sizeof output;
  size_t result = iconv(convert, &from, &left, &to, &room);
  iconv_close(convert);
  return result == (size_t)-1 || left != 0 || memcmp(output, "\xc3\xa9", 2) != 0;
}
