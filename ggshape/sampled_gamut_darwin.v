module ggshape

import gg.canvas
import math

// Mipmaps and hardware filtering remain in the image's sRGB encoding. The
// sampled, unpremultiplied color converts before destination-space blending.
pub fn draw_sampled_srgb_gamut_clipped(pixels &u8, width i32, height i32, pitch i32,
	backdrop i32, source []u8, sw int, sh int, x f32, y f32, dw f32, dh f32,
	samples int, nw int, nh int, clip [12]f32, gpu_mips bool, gamut [9]f32) i32 {
	if !canvas.document_image_srgb_gamut_supported() || sw <= 0 || sh <= 0
		|| sw > 4096 || sh > 4096 || sw * sh > 4 * 1024 * 1024
		|| source.len != sw * sh * 4 || gamut.any(!math.is_finite(it)) {
		return 0
	}
	return draw_sampled_image_color(pixels, width, height, pitch, backdrop,
		source, [], sw, sh, x, y, dw, dh, samples, nw, nh, clip, gpu_mips,
		unsafe { nil }, 0, false, [2]f32{}, false,
		canvas.DocumentImageColorTransform{gamma: -1, gamut: gamut})
}
