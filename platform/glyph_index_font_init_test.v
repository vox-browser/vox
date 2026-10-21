module platform

import x.ttf

fn glyph_index_test_face(bytes []u8) &ttf.TTF_File {
	return &ttf.TTF_File{buf:bytes, panose_array:[]u8{len:12}, width_scale:1}
}

fn test_glyph_index_initializer_preserves_metadata_metrics_outlines_and_kerning() {
	$if vox_sparse_ttf ? {
		for name in ['SerenitySans-Regular.ttf', 'NotoEmoji.ttf'] {
			path := bundled_font_path(name) or { panic('missing ${name}') }
			mut bytes := read_outline_face_bytes(path, 0) or { panic('missing face') }
			normalize_table_checksums(mut bytes)
			mut original := glyph_index_test_face(bytes)
			original.init()
			mut sparse := glyph_index_test_face(bytes)
			sparse.init_for_glyph_indices()
			assert original.cmaps.len > 0
			assert sparse.cmaps.len == 0
			assert sparse.tables == original.tables
			assert sparse.units_per_em == original.units_per_em
			assert sparse.length == original.length
			assert sparse.font_family == original.font_family
			assert sparse.font_sub_family == original.font_sub_family
			assert sparse.full_name == original.full_name
			assert sparse.postscript_name == original.postscript_name
			assert sparse.panose_array == original.panose_array
			assert sparse.ascent == original.ascent
			assert sparse.descent == original.descent
			assert sparse.line_gap == original.line_gap
			original.reset_kern()
			sparse.reset_kern()
			for character in 'AVTo0éß漢'.runes() {
				index := font_cmap_glyph(bytes, u32(character))
				assert index == original.map_code(int(character))
				a, b := original.get_horizontal_metrics(index)
				c, d := sparse.get_horizontal_metrics(index)
				assert a == c && b == d
				kern_a, kern_b := original.next_kern(int(index))
				kern_c, kern_d := sparse.next_kern(int(index))
				assert kern_a == kern_c && kern_b == kern_d
				if font_face_has_truetype_outlines(sparse) {
					left, right, top, bottom := original.read_glyph_dim(index)
					x, y, z, w := sparse.read_glyph_dim(index)
					assert left == x && right == y && top == z && bottom == w
					old := original.read_glyph(index)
					actual := sparse.read_glyph(index)
					assert actual.points == old.points
					assert actual.contour_ends == old.contour_ends
					assert actual.valid_glyph == old.valid_glyph
				}
			}
		}
	}
}

fn test_glyph_index_initialization_allocates_no_discarded_dense_unicode_vectors() {
	$if vox_sparse_ttf ? {
		$if !prealloc { return }
		path := bundled_font_path('SerenitySans-Regular.ttf') or { panic('missing test font') }
		mut bytes := read_outline_face_bytes(path, 0) or { panic('missing face') }
		normalize_table_checksums(mut bytes)
		mut original_storage := new_arena('original dense font initializer')
		entry := original_storage.enter()
		mut original := glyph_index_test_face(bytes)
		original.init()
		original_storage.leave(entry)
		mut sparse_storage := new_arena('glyph-index font initializer')
		sparse_entry := sparse_storage.enter()
		mut sparse := glyph_index_test_face(bytes)
		sparse.init_for_glyph_indices()
		sparse_storage.leave(sparse_entry)
		assert original_storage.usage().used - sparse_storage.usage().used >= 65536 * sizeof(int)
		assert sparse.cmaps.len == 0 && sparse.units_per_em == original.units_per_em
		original_storage.release()
		advance, _ := sparse.get_horizontal_metrics(font_cmap_glyph(bytes, u32(`A`)))
		assert advance > 0
		sparse_storage.release()
	}
}
