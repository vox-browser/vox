module main

import math

// Decode at the picture's rendering density. A lower-density capture may
// subsequently sample that texture, but must not select a smaller decode.
fn sampled_png_decode_extent(capture_extent [2]f64, rendering_density f64,
	capture_density f64) ?[2]f64 {
	for value in [capture_extent[0], capture_extent[1], rendering_density, capture_density] {
		if !math.is_finite(value) || value <= 0 { return none }
	}
	ratio := rendering_density / capture_density
	extent := [capture_extent[0] * ratio, capture_extent[1] * ratio]!
	if extent.any(!math.is_finite(it) || it <= 0) { return none }
	return extent
}
