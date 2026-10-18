module main

import math
import painting

struct ChromiumSVGBackgroundReplay {
 viewport_width int
 viewport_height int
 transform [6]f64
}

// SVG images lay out in an independently rounded container, then scale their
// recorded picture back to the fractional CSS tile size. Rounding both tile
// edges instead changes the viewBox scale at half-pixel background positions.
fn chromium_svg_background_replay(tile painting.Rect, outer [6]f64) ChromiumSVGBackgroundReplay {
 width := math.max(f64(1.0 / 64.0), math.trunc(tile.width * 64) / 64)
 height := math.max(f64(1.0 / 64.0), math.trunc(tile.height * 64) / 64)
 viewport_width := math.max(1, int(math.floor(width + .5)))
 viewport_height := math.max(1, int(math.floor(height + .5)))
 local := [width / f64(viewport_width), f64(0), 0, height / f64(viewport_height),
  math.floor(tile.x + .5), math.floor(tile.y + .5)]!
 return ChromiumSVGBackgroundReplay{viewport_width, viewport_height,
  [outer[0]*local[0], outer[1]*local[0], outer[2]*local[3], outer[3]*local[3],
   outer[0]*local[4]+outer[2]*local[5]+outer[4],
   outer[1]*local[4]+outer[3]*local[5]+outer[5]]!}
}
