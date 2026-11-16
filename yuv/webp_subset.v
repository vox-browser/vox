module yuv

import math

// Fold an in-bounds source subset into the full plane destination. Limit this
// path to near-half sampling or bounded magnification and integral geometry,
// where the caller can retain the original destination clip.
pub fn webp_atlas_subset_destination(width int, height int, source [4]f32,
	destination [4]f32) ?[4]f32 {
	if width <= 0 || height <= 0 || source.any(!math.is_finite(it))
		|| destination.any(!math.is_finite(it)) || source[0] < 0 || source[1] < 0
		|| source[2] <= 0 || source[3] <= 0 || source[0] + source[2] > width
		|| source[1] + source[3] > height || destination[2] <= 0 || destination[3] <= 0 {
		return none
	}
	mut subset := source
	if destination[2] > source[2] && destination[3] > source[3] {
		// Density conversion can leave an integral source edge one float32
		// roundoff away from its integer. Admit only that roundoff for enlargement;
		// fractional crops continue through the established fallback.
		for i, value in source {
			rounded := f32(math.round(value))
			if math.abs(value - rounded) > math.max(f32(1), math.abs(value)) * f32(1.1920928955078125e-7) {
				return none
			}
			subset[i] = rounded
		}
	}
	if subset[2] <= 0 || subset[3] <= 0 { return none }
	sx, sy := destination[2] / subset[2], destination[3] / subset[3]
	full := [destination[0] - subset[0] * sx, destination[1] - subset[1] * sy, f32(width) * sx,
		f32(height) * sy]!
	if full.any(!math.is_finite(it) || it != math.floor(it))
		|| full[2] * 2 <= width || full[3] * 2 <= height
		|| !webp_atlas_sampling_supported(width, height, f64(full[2]), f64(full[3])) {
		return none
	}
	return full
}
