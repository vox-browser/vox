module main

import math
import painting

struct ChromiumSVGBackgroundReplay {
 viewport_width int
 viewport_height int
 transform [6]f64
}

// Non-repeating SVG backgrounds lay out in an independently rounded container.
// Blink maps that picture to the snapped destination, whose dimensions match
// the rounded container; fractional CSS tile dimensions do not scale it again.
fn chromium_svg_background_replay(tile painting.Rect, outer [6]f64) ChromiumSVGBackgroundReplay {
 width := math.max(f64(1.0 / 64.0), math.trunc(tile.width * 64) / 64)
 height := math.max(f64(1.0 / 64.0), math.trunc(tile.height * 64) / 64)
 viewport_width := math.max(1, int(math.floor(width + .5)))
 viewport_height := math.max(1, int(math.floor(height + .5)))
 local := [f64(1), f64(0), 0, f64(1),
  math.floor(tile.x + .5), math.floor(tile.y + .5)]!
 return ChromiumSVGBackgroundReplay{viewport_width, viewport_height,
  [outer[0]*local[0], outer[1]*local[0], outer[2]*local[3], outer[3]*local[3],
   outer[0]*local[4]+outer[2]*local[5]+outer[4],
   outer[1]*local[4]+outer[3]*local[5]+outer[5]]!}
}
