module cpuraster

import crypto.sha256
import os

fn test_freetype_masks_match_native_outline_rasterization() {
	$if linux || cpuraster_freetype ? {
		font := os.join_path(@VMODROOT, 'pixel_tests/sites/tarsnap/www.tarsnap.com/font/NotoSans-Regular-subset.ttf')
		run := CanvasGlyphRun{
			font_path:   font
			font_size:   17
			glyphs:      [u16(5), 9, 12, 7]
			positions:   [f32(0), 0, 9.3, 0, 18.55, 0, 27.8, 0]
			translation: [f32(3.25), 26.6]!
		}
		transforms := [[f32(1), 0, 0, 1, 0, 0]!, [f32(1.25), 0, 0, 0.75, 2, 4]!,
			[f32(0.9), 0.3, -0.3, 0.9, 4, -2]!]
		// Original canvas call, with the native FreeType face factory and the
		// same FreeType library as the differential oracle.
		hashes := $if linux {
			['bf0dab340c75632d472b66b265ec47d481bc4a6ec7b062e114e0e21dd5dd3458',
			'92294b06864eb552d2c073da90ca539eb66f44b1e655e4c806f8f737fe46d4ec',
			'2c0464e96cfd56d5cd22a4196f1d2bf673043d15037f30c5ba46b2f0f07d886c']
		} $else {
			['ab3ae9f259306087962f757c1003cddd801aeb572ac6be36f28ca40965df2f94',
			'954a41f50d8fc61b24a2c7992e056e6e5a1634c0ab1335d0416ee7ebbd03c54e',
			'5fb98bbdf48141884566c8c9a461d6074431010bafb42425d5b3b6fa04744b44']
		}
		for i, transform in transforms {
			mut pixels := []u8{len: 48 * 40 * 4}
			assert fill_canvas_glyphs(mut pixels, 48, 40, 192, 2, run, transform, 0xff3070c0,
				none, 1, .src_over, [], none)
			assert sha256.sum(pixels).hex() == hashes[i]
		}
	}
}

fn test_freetype_path_strikes_keep_quadratic_outlines() {
	$if linux || cpuraster_freetype ? {
		face := open_glyph_face(os.join_path(@VMODROOT, 'pixel_tests/sites/tarsnap/www.tarsnap.com/font/NotoSans-Regular-subset.ttf')) or { panic('face') }
		defer { face.release() }
		mut strike := new_glyph_strike(face, glyph_path_size, SkAffine{}, 0) or { panic('strike') }
		defer { strike.release() }
		outline := glyph_outline(strike.font, 5, strike.transform) or { panic('outline') }
		assert outline.verbs.len > 0
		assert outline.verbs.contains(.quad)
		assert outline.verbs.last() == .close
	}
}
