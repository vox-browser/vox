module layout

import platform

fn test_context_slices_keep_space_kerning_and_own_their_glyph_arrays() {
	font := &platform.Font{
		family:                'Test'
		point_size:            10
		font_rendering_policy: .chromium
	}
	mut full := platform.GlyphRun.new(font, .ltr, [
		platform.Glyph{ code_point: u32(`N`), advance: 7, length_in_code_units: 1 },
		platform.Glyph{
			code_point:           u32(` `)
			position:             platform.GlyphPosition{
				x: 7
			}
			advance:              2.25
			length_in_code_units: 1
		},
		platform.Glyph{
			code_point:           u32(`A`)
			position:             platform.GlyphPosition{
				x: 9.25
			}
			advance:              7
			length_in_code_units: 1
		},
	])
	space := chromium_context_slice(full, TextNodeChunk{ start: 1, length: 1 }) or {
		panic('space missing')
	}
	letter := chromium_context_slice(full, TextNodeChunk{ start: 2, length: 1 }) or {
		panic('letter missing')
	}
	assert space.glyph_run.width() == 2.25
	assert space.trailing_whitespace.advance == 2.25
	assert space.trailing_whitespace.length_in_code_units == 1
	assert letter.glyph_run.glyphs_[0].position.x == 0
	assert letter.glyph_run.width() == 7
	full.glyphs_[1].advance = 99
	assert space.glyph_run.glyphs_[0].advance == 2.25
	ligature := platform.GlyphRun.new(font, .ltr, [
		platform.Glyph{ code_point: u32(`f`), advance: 10, length_in_code_units: 2 },
	])
	assert chromium_context_slice(ligature, TextNodeChunk{ start: 1, length: 1 }) == none
}
