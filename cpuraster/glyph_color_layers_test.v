module cpuraster

import crypto.sha256
import os

fn test_portable_layered_color_glyph_masks_and_vector_drawables() {
	$if linux || cpuraster_freetype ? {
		font := os.join_path(@VMODROOT, 'cpuraster/testdata/color-layers.ttf')
		sizes := [f32(17), 44, 320, 280]
		transforms := [[f32(1), 0, 0, 1, 0, 0]!, [f32(.9), .3, -.3, .9, 4, -2]!, [f32(1), 0, 0,
			1, 0, 0]!, [f32(.9), .3, -.3, .9, 4, -2]!]
		// Original native FreeType canvas calls. The two large sizes replay
		// canonical outlines through saved layers; the small ones are sprites.
		hashes := ['1b789b902a4cf0016efa8dc1973281a4089c060755d5161d744b7554ad640113',
			'5bf5ff64fe62b2a085763b1c6dfb836977ca2ed31824247d64e5cd31f5fcf295',
			'696774b726410bcfead267b3baa9d6d314f39a9bf9c4a31051bfb8a7d1cf6585',
			'0eca60013e0df80a32d6aa5df65adca4c437d6c0248d0bafee193ea67630a8d5']
		for i, size in sizes {
			run := CanvasGlyphRun{
				font_path:   font
				font_size:   size
				glyphs:      [u16(1)]
				positions:   [f32(0), 0]
				translation: [f32(3.25), 26.6]!
			}
			mut pixels := []u8{len: 48 * 40 * 4}
			assert fill_canvas_glyphs(mut pixels, 48, 40, 192, 2, run, transforms[i], 0x7f306090,
				none, .7, .src_over, [], none)
			assert sha256.sum(pixels).hex() == hashes[i]
		}
	}
}

fn test_offscreen_color_drawable_still_applies_transparency_affecting_restore() {
	$if linux || cpuraster_freetype ? {
		run := CanvasGlyphRun{
			font_path: os.join_path(@VMODROOT, 'cpuraster/testdata/color-layers.ttf')
			font_size: 320
			glyphs:    [u16(1), 1]
			positions: [f32(0), 0, 10000, 0]
		}
		mut pixels := []u8{len: 16 * 16 * 4, init: 255}
		assert fill_canvas_glyphs(mut pixels, 16, 16, 64, 2, run, [f32(1), 0, 0, 1, 0, 0]!,
			0xffffffff, none, 1, .src_in, [], none)
		assert pixels.all(it == 0)
	}
}
