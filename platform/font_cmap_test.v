module platform

import x.ttf

fn test_compact_font_cmap_matches_the_legacy_mapper_for_every_bmp_code_point() {
	path := bundled_font_path('SerenitySans-Regular.ttf') or { panic('missing bundled font') }
	mut bytes := read_outline_face_bytes(path, 0) or { panic('missing font bytes') }
	normalize_table_checksums(mut bytes)
	mut legacy := &ttf.TTF_File{buf: bytes, panose_array: []u8{len: 12}, width_scale: 1}
	legacy.init()
	for code_point in 0 .. 65536 {
		assert font_cmap_glyph(bytes, u32(code_point)) == legacy.map_code(code_point), '${code_point}'
	}
	assert font_cmap_glyph(bytes, 0x10000) == 0
	assert font_cmap_glyph(bytes, 0x10ffff) == 0
	font := &Font{family: 'CompactCmapFixture', point_size: 16, source_path: path}
	face := font_face(font) or { panic('missing compact face') }
	assert face.cmaps.len == 0
	assert face.cmaps.cap == 0
	for code_point in [u32(`A`), u32(`x`), u32(`0`), u32(0x03bb)] {
		glyph := legacy.map_code(int(code_point))
		advance, _ := legacy.get_horizontal_metrics(glyph)
		actual_advance, actual_glyph := font.glyph_metrics_for_shaping(code_point)
		assert actual_glyph == int(glyph)
		assert font.contains_glyph(code_point) == (glyph != 0)
		assert actual_advance == f32(advance) * font.point_size / f32(legacy.units_per_em)
	}
	assert !font.contains_glyph(0x10000)
}

fn test_compact_font_cmap_supplies_x_height_without_os2_metrics() {
	path := bundled_font_path('SerenitySans-Regular.ttf') or { panic('missing bundled font') }
	mut bytes := read_outline_face_bytes(path, 0) or { panic('missing font bytes') }
	normalize_table_checksums(mut bytes)
	mut face := &ttf.TTF_File{buf: bytes, panose_array: []u8{len: 12}, width_scale: 1}
	face.init()
	x_glyph := face.map_code(int(`x`))
	assert x_glyph != 0
	_, _, _, y_max := face.read_glyph_dim(x_glyph)
	if os2 := font_table_offset(face.buf, 'OS/2') {
		// Version 1 has no sxHeight; the font must measure the x glyph.
		face.buf[os2] = 0
		face.buf[os2 + 1] = 1
	}
	face.cmaps = face.cmaps[..0].clone()
	font := &Font{family: 'CompactXHeightFixture', point_size: 16, decoded_face_: face}
	assert font.pixel_metrics().x_height == f32(y_max) * 16 / f32(face.units_per_em)
}

fn test_compact_font_cmap_rejects_truncated_tables_and_range_offsets() {
	for length in 0 .. 32 { assert font_cmap_glyph([]u8{len: length}, 65) == 0 }
	mut format4 := []u8{len: 24}
	format4[7] = 2
	format4[15] = 65
	format4[19] = 65
	format4[21] = 1
	assert font_cmap_format4_glyph(format4, 65) == 66
	format4[23] = 255
	assert font_cmap_format4_glyph(format4, 65) == 0
	for length in 0 .. 24 {
		assert font_cmap_format4_glyph(format4[..length], 65) == 0
	}
}

fn test_compact_font_cmap_format0_encoding_selection_and_last_map_precedence() {
	mut bytes := []u8{len: 56 + 262 * 3}
	bytes[5] = 1
	copy(mut bytes[12..16], 'cmap'.bytes())
	write_sfnt_u32(mut bytes, 20, 28)
	write_sfnt_u32(mut bytes, 24, u32(bytes.len - 28))
	bytes[31] = 3
	for index in 0 .. 3 {
		record := 32 + index * 8
		bytes[record + 1] = if index == 0 { u8(0) } else { u8(3) }
		bytes[record + 3] = if index == 2 { u8(1) } else { u8(0) }
		start := 56 + index * 262
		write_sfnt_u32(mut bytes, record + 4, u32(start - 28))
		bytes[start + 2] = 1
		bytes[start + 3] = 6
		bytes[start + 6 + 65] = u8(3 + index * 2)
	}
	assert font_cmap_glyph(bytes, 65) == 7
	assert font_cmap_glyph(bytes, 256) == 0
	bytes[51] = 2
	assert font_cmap_glyph(bytes, 65) == 5
	bytes[41] = 0
	assert font_cmap_glyph(bytes, 65) == 0
}
