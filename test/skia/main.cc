#include <skia/core/SkBitmap.h>
#include <skia/core/SkCanvas.h>
#include <skia/core/SkPaint.h>
#include <cstdio>
#include <cstring>

#ifdef CME_EXPECT_PNG
#include <png.h>
#endif
#ifdef CME_EXPECT_FREETYPE
#include <ft2build.h>
#include FT_FREETYPE_H
#endif
#ifdef CME_EXPECT_HARFBUZZ
#include <harfbuzz/hb.h>
#endif

// The skia/ in front of the headers is this port's doing. Skia includes
// itself as "include/core/SkCanvas.h", a path with nothing in it to say
// whose include directory it is; the port offers that directory a second
// time under a name, so a consumer can say which library it meant.

namespace {

// A library that answers with a version other than the one the port pinned is
// not the library this build made. That is the failure worth catching here:
// a system copy satisfies the linker in silence, and everything works right
// up until it is a different version to the one that was checked.
bool same(const char *what, const char *found, const char *expected) {
  if (std::strncmp(found, expected, std::strlen(expected)) == 0) {
    std::printf("%s %s\n", what, found);
    return true;
  }
  std::printf("%s is %s and the port built %s\n", what, found, expected);
  return false;
}

} // namespace

int main() {
  bool ok = true;

#ifdef CME_EXPECT_PNG
  ok = same("libpng", png_get_libpng_ver(nullptr), CME_EXPECT_PNG) && ok;
#endif
#ifdef CME_EXPECT_FREETYPE
  {
    FT_Library library = nullptr;
    if (FT_Init_FreeType(&library) != 0) {
      std::printf("freetype did not start\n");
      return 1;
    }
    int major = 0, minor = 0, patch = 0;
    FT_Library_Version(library, &major, &minor, &patch);
    char version[32];
    std::snprintf(version, sizeof(version), "%d.%d.%d", major, minor, patch);
    ok = same("freetype", version, CME_EXPECT_FREETYPE) && ok;
    FT_Done_FreeType(library);
  }
#endif
#ifdef CME_EXPECT_HARFBUZZ
  ok = same("harfbuzz", hb_version_string(), CME_EXPECT_HARFBUZZ) && ok;
#endif

  // A CPU raster surface, one rectangle, one pixel read back. No codec, no
  // font, no GPU: exactly what a Skia with no features can do, and what it
  // still has to do with every feature on.
  SkBitmap bitmap;
  bitmap.allocN32Pixels(64, 64);
  SkCanvas canvas(bitmap);
  canvas.clear(SK_ColorBLACK);
  SkPaint paint;
  paint.setColor(SK_ColorRED);
  canvas.drawRect(SkRect::MakeXYWH(8, 8, 48, 48), paint);
  std::printf("%08x\n", bitmap.getColor(32, 32));
  return ok ? 0 : 1;
}
