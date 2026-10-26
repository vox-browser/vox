module platform

import x.ttf

fn test_normalized_font_initializer_preserves_checked_metadata_metrics_outlines_and_kerning() {
	$if vox_sparse_ttf ? {
		mut paths := []string{}
		for name in ['SerenitySans-Regular.ttf', 'NotoEmoji.ttf'] {
			paths << bundled_font_path(name) or { panic('missing ${name}') }
		}
		$if macos {
			paths << '/System/Library/Fonts/HelveticaNeue.ttc'
			paths << '/System/Library/Fonts/Supplemental/STIXGeneral.otf'
		}
		for path in paths {
			scratch := begin_thread_scratch('normalized font initializer comparison')
			mut bytes := read_outline_face_bytes(path, 0) or { panic('missing ${path}') }
			normalize_table_checksums(mut bytes)
			before := bytes.clone()
			mut reference := &ttf.TTF_File{ buf: bytes, panose_array: []u8{len: 12}, width_scale: 1 }
			reference.init()
			mut actual := decode_outline_face(mut bytes)
			assert bytes == before
			assert actual.tables == reference.tables
			assert actual.cmaps.len == 0
			assert actual.units_per_em == reference.units_per_em
			assert actual.length == reference.length
			assert actual.font_family == reference.font_family
			assert actual.font_sub_family == reference.font_sub_family
			assert actual.full_name == reference.full_name
			assert actual.postscript_name == reference.postscript_name
			assert actual.panose_array == reference.panose_array
			assert actual.ascent == reference.ascent
			assert actual.descent == reference.descent
			assert actual.line_gap == reference.line_gap
			for character in 'AVTo0xéß漢'.runes() {
				glyph := font_cmap_glyph(bytes, u32(character))
				x, y := actual.get_horizontal_metrics(glyph)
				a, b := reference.get_horizontal_metrics(glyph)
				assert x == a && y == b
				kx, ky := actual.next_kern(int(glyph))
				ka, kb := reference.next_kern(int(glyph))
				assert kx == ka && ky == kb
				if font_face_has_truetype_outlines(actual) {
					left := actual.read_glyph(glyph)
					right := reference.read_glyph(glyph)
					assert left.points == right.points
					assert left.contour_ends == right.contour_ends
					assert left.valid_glyph == right.valid_glyph
				}
			}
			scratch.finish()
		}
	}
}
