module platform

import os
import x.ttf

// PT Sans uses short (16-bit) loca entries and a glyf table larger than
// 64 KiB, so glyph 233 starts at glyf offset 78,926. A 16-bit shift of its
// loca entry would read another glyph's bytes (or past the buffer).
const loca_test_font = os.join_path(@VMODROOT, 'pixel_tests/sites/nghttp2/fonts.gstatic.com/s/ptsans/v18/jizaRExUiTo99u79D0KEwA.ttf')

fn loca_test_face() &ttf.TTF_File {
	mut bytes := os.read_bytes(loca_test_font) or { panic(err) }
	return decode_outline_face(mut bytes)
}

fn test_short_loca_glyphs_beyond_64_kib_keep_their_own_outline() {
	face := loca_test_face()
	assert face.index_to_loc_format == 0
	loca := font_table_offset(face.buf, 'loca') or { panic('missing loca') }
	assert (int(face.buf[loca + 2 * 233]) << 9 | int(face.buf[loca + 2 * 233 + 1]) << 1) == 78926
	font := &Font{family: 'ShortLocaFixture', point_size: 1000, decoded_face_: face}
	outline := font.glyph_outline(233) or { panic('missing outline beyond 64 KiB') }
	assert outline.contours.len == 1
	assert outline.contours[0] == [
		FontGlyphOutlinePoint{x: 324, y: 713, on_curve: true},
		FontGlyphOutlinePoint{x: 373, y: 675, on_curve: true},
		FontGlyphOutlinePoint{x: -140, y: -12, on_curve: true},
		FontGlyphOutlinePoint{x: -190, y: 27, on_curve: true},
	]
	assert font.glyph_bounds(233) == FontGlyphBounds{x_min: -190, x_max: 373, y_min: -12, y_max: 713}
}

fn test_glyph_indices_outside_the_face_have_no_outline() {
	face := loca_test_face()
	font := &Font{family: 'ShortLocaRangeFixture', point_size: 16, decoded_face_: face}
	assert face.length == 234
	assert font.glyph_outline(233) != none
	assert font.glyph_bounds(233) != FontGlyphBounds{}
	for glyph in [234, 1000, 0xffff] {
		assert font.glyph_outline(glyph) == none
		assert font.glyph_bounds(glyph) == FontGlyphBounds{}
	}
}
