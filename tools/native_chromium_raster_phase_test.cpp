#include "../native_chromium_raster_phase.h"
#include <cassert>
#include <initializer_list>
int main() {
 for (int scale : {1, 2, 3}) {
  for (int origin = -19; origin <= 19; ++origin) {
   for (int offset = -32; offset <= 32; ++offset) {
    int expected = (offset * scale % 8 + 8) % 8;
    assert(vox_chromium_dither_phase(origin + offset, origin, scale) == expected);
    assert(vox_chromium_dither_phase(origin + offset + 8, origin, scale) == expected);
   }
  }
 }
 assert(vox_chromium_dither_phase(72, 67, 1) == 5);
 assert(vox_chromium_dither_phase(10.5, 3.5, 2) == 6);
}
