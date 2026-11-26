module cpuraster

import math

// Blend an A8 glyph mask with an unpremultiplied floating-point source.
// A GPU document color transform can produce RGB outside [0, 1]. Keep it
// through coverage/source-over and clamp only when storing the destination.
// This explicit route leaves the ordinary Canvas raster pipeline unchanged.
pub fn blend_extended_glyph_mask(mut pixels []u8, width int, height int, pitch int,
	mask []u8, color [4]f32) bool {
	if width <= 0 || height <= 0 || pitch < width * 4 || height > pixels.len / pitch
		|| height > mask.len / width || mask.len != width * height
		|| color.any(!math.is_finite(it)) || color[3] < 0 || color[3] > 1 { return false }
	for y in 0 .. height {
		for x in 0 .. width {
			coverage := mask[y * width + x]
			if coverage == 0 { continue }
			alpha := f32(coverage) * inv_255 * color[3]
			inverse := highp_inv(alpha)
			at := y * pitch + x * 4
			for channel in 0 .. 3 {
				source := color[channel] * alpha
				destination := f32(pixels[at + channel]) * inv_255
				pixels[at + channel] = highp_to_byte(mad(destination, inverse, source))
			}
			pixels[at + 3] = highp_to_byte(mad(f32(pixels[at + 3]) * inv_255, inverse, alpha))
		}
	}
	return true
}
