module cpuraster

import crypto.sha256
import os

fn test_portable_bitmap_glyphs_keep_color_mipmaps_and_rotated_origins() {
	$if linux || cpuraster_freetype ? {
		font := os.join_path(@VMODROOT, 'cpuraster/testdata/bitmap-color.ttf')
		sizes := [f32(17), 3.5, 44.16234]
		transforms := [[f32(1), 0, 0, 1, 0, 0]!, [f32(1), 0, 0, 1, 0, 0]!,
			[f32(0.71378213), -0.9609574, 1.045179, 0.71378213, 17.57825, 26.452244]!]
		// Native FreeType face, original canvas call: full-size, mipmapped,
		// and a rotation whose nonzero bitmap origin needs SkM44 arithmetic.
		hashes := ['638a005732ba062b87403417a0ce2f1ebfbce2063453e36d04c149089a12f263',
			'7f0b59bac3e83141a97cf52310ae1dae6022040f8641a88018feda7fbaeb2481',
			'fcf40edf0d666015ee2159eddd418fdf25e8f7e7423f209e4818dcbcafc831fd']
		for i, size in sizes {
			run := CanvasGlyphRun{
				font_path:   font
				font_size:   size
				glyphs:      [u16(1)]
				positions:   [f32(0), 0]
				translation: [f32(3.25), 26.6]!
			}
			mut pixels := []u8{len: 48 * 40 * 4}
			assert fill_canvas_glyphs(mut pixels, 48, 40, 192, 2, run, transforms[i], 0xffffffff,
				none, 1, .src_over, [], none)
			assert sha256.sum(pixels).hex() == hashes[i]
		}
	}
}

fn test_portable_color_glyph_ignores_an_invalid_pattern_shader() {
	$if linux || cpuraster_freetype ? {
		run := CanvasGlyphRun{
			font_path:   os.join_path(@VMODROOT, 'cpuraster/testdata/bitmap-color.ttf')
			font_size:   17
			glyphs:      [u16(1)]
			positions:   [f32(0), 0]
			translation: [f32(3.25), 26.6]!
		}
		mut plain := []u8{len: 48 * 40 * 4}
		mut patterned := plain.clone()
		identity := [f32(1), 0, 0, 1, 0, 0]!
		assert fill_canvas_glyphs(mut plain, 48, 40, 192, 2, run, identity, 0xffffffff,
			none, 1, .src_over, [], none)
		pattern := CanvasPattern{
			pixels:        [u8(255), 0, 0, 255]
			width:         1
			height:        1
			pitch:         4
			premultiplied: true
			transform:     [f32(2), 1, 4, 2, 3, -5]!
		}
		assert fill_canvas_glyphs(mut patterned, 48, 40, 192, 2, run, identity, 0xffffffff,
			pattern, 1, .src_over, [], none)
		assert patterned == plain
	}
}
