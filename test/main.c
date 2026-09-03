#include <sndfile.h>
#include <png.h>
#include <minimp3_ex.h>
#include <stdio.h>

/* Nothing is decoded here. The point of the test is that it configures,
   compiles and links: the headers were found, the archives were built, and
   one find_package brought the four libraries libsndfile reads. */
int main(void) {
  mp3dec_t decoder;
  mp3dec_init(&decoder);
  printf("%s\n", sf_version_string());
  printf("%s\n", png_get_libpng_ver(NULL));
  return 0;
}
