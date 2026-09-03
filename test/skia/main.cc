#include <skia/core/SkBitmap.h>
#include <skia/core/SkCanvas.h>
#include <skia/core/SkPaint.h>
#include <cstdio>

// A CPU raster surface, one rectangle, one pixel read back. No codec, no
// font, no GPU: exactly what a Skia with no features can do.
//
// The skia/ in front of the headers is this port's doing. Skia includes
// itself as "include/core/SkCanvas.h", a path with nothing in it to say
// whose include directory it is; the port offers that directory a second
// time under a name, so a consumer can say which library it meant.
int main() {
  SkBitmap bitmap;
  bitmap.allocN32Pixels(64, 64);
  SkCanvas canvas(bitmap);
  canvas.clear(SK_ColorBLACK);
  SkPaint paint;
  paint.setColor(SK_ColorRED);
  canvas.drawRect(SkRect::MakeXYWH(8, 8, 48, 48), paint);
  std::printf("%08x\n", bitmap.getColor(32, 32));
  return 0;
}
