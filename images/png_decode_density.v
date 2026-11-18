module main

import math
import imageraster

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

fn sampled_png_decode_size(width int, height int, raster_extent [2]f64,
	decode_extent [2]f64) ?(int, int) {
	decoded_width, decoded_height := imageraster.decode_size(width, height, decode_extent[0],
		decode_extent[1]) or {
		if raster_extent == decode_extent { return none }
		// The live density calls for the full source. Use it when the target
		// still minifies the image and its dimensions support this sampler.
		imageraster.decode_size(width, height, raster_extent[0], raster_extent[1]) or {
			return none
		}
		return width, height
	}
	return decoded_width, decoded_height
}
