module platform

import os
import x.ttf

fn outline_format_test_truetype_face() &ttf.TTF_File {
	path := bundled_font_path('SerenitySans-Regular.ttf') or { panic('missing test font') }
	mut bytes := os.read_bytes(path) or { panic(err) }
	normalize_table_checksums(mut bytes)
	mut face := &ttf.TTF_File{buf: bytes, panose_array: []u8{len: 12}, width_scale: 1}
	face.init()
	return face
}

fn test_non_truetype_faces_skip_glyph_geometry_without_losing_horizontal_metrics() {
	for removed in [['glyf'], ['loca'], ['glyf', 'loca']] {
		mut face := outline_format_test_truetype_face()
		glyph := int(face.map_code(int(`A`)))
		advance, _ := face.get_horizontal_metrics(u16(glyph))
		for tag in removed { face.tables.delete(tag) }
		font := &Font{family: 'OutlineFormatFixture', point_size: 16, decoded_face_: face}
		assert !font_face_has_truetype_outlines(face)
		assert font.glyph_outline(glyph) == none
		assert font.glyph_bounds(glyph) == FontGlyphBounds{}
		measured, index := font.glyph_metrics(u32(`A`))
		assert index == glyph
		assert measured == f32(advance) * 16 / f32(face.units_per_em)
	}
}

fn test_non_truetype_faces_without_os2_x_height_keep_the_half_em_metrics_fallback() {
	mut face := outline_format_test_truetype_face()
	face.tables.delete('glyf')
	face.tables.delete('loca')
	if os2 := font_table_offset(face.buf, 'OS/2') {
		face.buf[os2] = 0
		face.buf[os2 + 1] = 1
	}
	font := &Font{family: 'OutlineFormatMetricsFixture', point_size: 16, decoded_face_: face}
	metrics := font.pixel_metrics_uncached()
	assert metrics.x_height == f32(face.units_per_em / 2) * 16 / f32(face.units_per_em)
	assert metrics.ascent > 0
	assert metrics.advance_of_ascii_zero > 0
}

fn test_truetype_glyph_bounds_and_contours_keep_the_existing_reader_results() {
	mut face := outline_format_test_truetype_face()
	font := &Font{family: 'OutlineFormatTrueTypeFixture', point_size: 16, decoded_face_: face}
	assert font_face_has_truetype_outlines(face)
	for character in [`A`, `x`, `0`] {
		glyph := face.map_code(int(character))
		x_min, x_max, y_min, y_max := face.read_glyph_dim(glyph)
		scale := f32(16) / f32(face.units_per_em)
		assert font.glyph_bounds(int(glyph)) == FontGlyphBounds{x_min: f32(x_min) * scale, x_max: f32(x_max) * scale, y_min: f32(y_min) * scale, y_max: f32(y_max) * scale}
		original := face.read_glyph(glyph)
		outline := font.glyph_outline(int(glyph)) or { panic('missing TrueType outline') }
		assert outline.contours.len == original.contour_ends.len
		mut point_index := 0
		for contour in outline.contours {
			for point in contour {
				assert point.x == f32(original.points[point_index].x) * scale
				assert point.y == f32(original.points[point_index].y) * scale
				assert point.on_curve == original.points[point_index].on_curve
				point_index++
			}
		}
		assert point_index == original.points.len
	}
}

fn test_installed_cff_font_keeps_metrics_and_reports_unavailable_truetype_geometry() {
	$if macos {
		path := '/System/Library/Fonts/Supplemental/STIXGeneral.otf'
		assert os.is_file(path)
		font := &Font{family: 'OutlineFormatRealCFFFixture', source_path: path, point_size: 16}
		face := font_face(font) or { panic('failed to load installed CFF fixture') }
		assert 'CFF ' in face.tables
		assert !font_face_has_truetype_outlines(face)
		_, glyph := font.glyph_advance_and_index(u32(`A`))
		assert glyph > 0
		assert font.glyph_outline(glyph) == none
		assert font.glyph_bounds(glyph) == FontGlyphBounds{}
		assert font.pixel_metrics().ascent > 0
	}
}
