#include "include/core/SkBitmap.h"
#include "include/core/SkCanvas.h"
#include "include/core/SkPaint.h"
#include <cstdio>

// A CPU raster surface, one rectangle, one pixel read back. No codec, no
// font, no GPU: exactly what a Skia with no features can do.
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
