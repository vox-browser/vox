module main

import math

// Decode for the raster target, with the document's rendering density as a
// floor. A smaller capture samples the same image detail as the live frame.
fn sampled_png_decode_extent(raster_extent [2]f64, rendering_density f64,
	raster_density f64) ?[2]f64 {
	for value in [raster_extent[0], raster_extent[1], rendering_density, raster_density] {
		if !math.is_finite(value) || value <= 0 { return none }
	}
	if rendering_density <= raster_density { return raster_extent }
	ratio := rendering_density / raster_density
	extent := [raster_extent[0] * ratio, raster_extent[1] * ratio]!
	if extent.any(!math.is_finite(it) || it <= 0) { return none }
	return extent
}
