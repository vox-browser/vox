module ggshape

import gg.canvas
import imageraster
import math
import os

const sampled_gamut_before_filter = os.getenv('VOX_DIAGNOSTIC_IMAGE_GAMUT_BEFORE_FILTER') == '1'

// Mipmaps and hardware filtering remain in the image's sRGB encoding. The
// sampled, unpremultiplied color converts before destination-space blending.
pub fn draw_sampled_srgb_gamut_clipped(pixels &u8, width i32, height i32, pitch i32,
	backdrop i32, source []u8, sw int, sh int, x f32, y f32, dw f32, dh f32,
	samples int, nw int, nh int, clip [12]f32, gpu_mips bool, gamut [9]f32) i32 {
	return draw_sampled_srgb_gamut_with_shadow(pixels, width, height, pitch, backdrop,
		source, sw, sh, x, y, dw, dh, samples, nw, nh, clip, gpu_mips, gamut, unsafe { nil })
}

pub fn draw_sampled_srgb_gamut_with_shadow(pixels &u8, width i32, height i32, pitch i32,
	backdrop i32, source []u8, sw int, sh int, x f32, y f32, dw f32, dh f32,
	samples int, nw int, nh int, clip [12]f32, gpu_mips bool, gamut [9]f32,
	shadow &C.VoxGraphiteShape) i32 {
	return draw_sampled_srgb_gamut_with_shadow_and_glyphs(pixels, width, height, pitch, backdrop,
		source, sw, sh, x, y, dw, dh, samples, nw, nh, clip, gpu_mips, gamut, shadow, [])
}

// Keep overlapping A8 text and the image's edge samples until the same resolve.
pub fn draw_sampled_srgb_gamut_with_shadow_and_glyphs(pixels &u8, width i32, height i32, pitch i32,
	backdrop i32, source []u8, sw int, sh int, x f32, y f32, dw f32, dh f32,
	samples int, nw int, nh int, clip [12]f32, gpu_mips bool, gamut [9]f32,
	shadow &C.VoxGraphiteShape, glyphs []GlyphCoverage) i32 {
	if !canvas.document_image_srgb_gamut_supported() || sw <= 0 || sh <= 0
		|| sw > 4096 || sh > 4096 || sw * sh > 4 * 1024 * 1024
		|| source.len != sw * sh * 4 || gamut.any(!math.is_finite(it)) {
		return 0
	}
	if sampled_gamut_before_filter {
		converted := convert_image_srgb_gamut(imageraster.Image{
			width: sw
			height: sh
			pixels: source
		}, gamut) or { return 0 }
		eprintln('VOX_IMAGE_GAMUT_BEFORE_FILTER source=${sw}x${sh} gpu_mips=${gpu_mips}')
		return draw_sampled_image_color_with_glyphs(pixels, width, height, pitch, backdrop,
			converted, [], sw, sh, x, y, dw, dh, samples, nw, nh, clip, gpu_mips,
			shadow, 0, false, [2]f32{}, false, canvas.DocumentImageColorTransform{}, glyphs)
	}
	return draw_sampled_image_color_with_glyphs(pixels, width, height, pitch, backdrop,
		source, [], sw, sh, x, y, dw, dh, samples, nw, nh, clip, gpu_mips,
		shadow, 0, false, [2]f32{}, false,
		canvas.DocumentImageColorTransform{gamma: -1, gamut: gamut}, glyphs)
}
