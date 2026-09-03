#include <ft2build.h>
#include FT_FREETYPE_H
#include <FLAC/format.h>
#include <stdio.h>

/* Configures, compiles, links. The point is which libraries were reached and
   with what, not what they compute. */
int main(void) {
  FT_Library library = NULL;
  FT_Init_FreeType(&library);
  printf("%s\n", FLAC__VERSION_STRING);
  return 0;
}
