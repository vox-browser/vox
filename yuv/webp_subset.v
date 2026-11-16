module yuv

import math

// Fold an in-bounds source subset into the full plane destination. Limit this
// path to near-half sampling and integral geometry, where the caller can keep
// its original destination clip without introducing a new antialiased edge.
pub fn webp_atlas_subset_destination(width int, height int, source [4]f32,
	destination [4]f32) ?[4]f32 {
	if width <= 0 || height <= 0 || source.any(!math.is_finite(it))
		|| destination.any(!math.is_finite(it)) || source[0] < 0 || source[1] < 0
		|| source[2] <= 0 || source[3] <= 0 || source[0] + source[2] > width
		|| source[1] + source[3] > height || destination[2] <= 0 || destination[3] <= 0 {
		return none
	}
	sx, sy := destination[2] / source[2], destination[3] / source[3]
	full := [destination[0] - source[0] * sx, destination[1] - source[1] * sy,
		f32(width) * sx, f32(height) * sy]!
	if full.any(!math.is_finite(it) || it != math.floor(it))
		|| full[2] * 2 <= width || full[3] * 2 <= height
		|| !webp_atlas_sampling_supported(width, height, f64(full[2]), f64(full[3])) {
		return none
	}
	return full
}
