module yuv

import math

// Keep limited-range BT.601 components fractional until destination coverage.
// Native-size images sample 4:2:0 chroma at luma centers. Half-size uploads
// reduce luma to bytes first, then use the original chroma at full resolution.
// Other scales retain their existing painter until plane filtering is verified.
pub fn webp_sampled_colors(planes []u8, width int, height int, target_width int,
	target_height int) ?[]f32 {
	if width <= 0 || height <= 0 || width > 4096 || height > 4096
		|| width * height > 4 * 1024 * 1024 || width % 2 != 0 || height % 2 != 0
		|| !((target_width == width && target_height == height)
			|| (target_width == width / 2 && target_height == height / 2)) {
		return none
	}
	ys, cs := width * height, width / 2 * (height / 2)
	if planes.len != ys + 2 * cs { return none }
	scaled := target_width != width
	data := if scaled {
		jpeg_scaled_planes(planes, width, height, target_width, target_height, true) or { return none }
	} else {
		planes
	}
	size := target_width * target_height
	mut colors := []f32{len: size * 4}
	for y in 0 .. target_height {
		for x in 0 .. target_width {
			i := y * target_width + x
			yy := f64(data[i]) / 255
			u := if scaled {
				f64(data[size + i])
			} else {
				jpeg_chroma_sample(data[ys..ys + cs], width / 2, height / 2, x, y, width, height)
			} / 255
			v := if scaled {
				f64(data[size * 2 + i])
			} else {
				jpeg_chroma_sample(data[ys + cs..], width / 2, height / 2, x, y, width, height)
			} / 255
			// SkYUVMath's Rec601 limited-range matrix and normalized offsets.
			for c, value in [1.164384 * yy + 1.596027 * v - .874202,
				1.164384 * yy - .391762 * u - .812968 * v + .531668,
				1.164384 * yy + 2.017232 * u - 1.085631] {
				colors[i * 4 + c] = f32(math.max(0, math.min(1, value)))
			}
			colors[i * 4 + 3] = 1
		}
	}
	return colors
}
