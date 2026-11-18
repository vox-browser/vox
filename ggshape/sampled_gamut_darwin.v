module ggshape

import gg.canvas
import imageraster

// Convert the premultiplied source before building mipmaps so filtering and
// blending both use the document's destination encoding.
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
	converted := convert_image_srgb_gamut(imageraster.Image{
		width: sw
		height: sh
		pixels: source
	}, gamut) or { return 0 }
	return draw_sampled_image_color_with_glyphs(pixels, width, height, pitch, backdrop,
		converted, [], sw, sh, x, y, dw, dh, samples, nw, nh, clip, gpu_mips,
		shadow, 0, false, [2]f32{}, false, canvas.DocumentImageColorTransform{}, glyphs)
}
