module platform

import os
import time
import x.ttf

$if gcboehm ? { fn C.GC_get_total_bytes() usize }

fn sfnt_storage_test_path() string {
	return os.join_path(os.temp_dir(), 'vox-sfnt-storage-${os.getpid()}-${time.sys_mono_now()}.ttc')
}

fn sfnt_storage_test_directory(mut bytes []u8, at int, tags []string, offsets []u32, lengths []u32) {
	write_sfnt_u32(mut bytes, at, 0x00010000)
	bytes[at + 4] = u8(tags.len >> 8)
	bytes[at + 5] = u8(tags.len)
	for index, tag in tags {
		record := at + 12 + index * 16
		for byte_index in 0 .. 4 { bytes[record + byte_index] = tag[byte_index] }
		write_sfnt_u32(mut bytes, record + 4, 0x12345678 + u32(index))
		write_sfnt_u32(mut bytes, record + 8, offsets[index])
		write_sfnt_u32(mut bytes, record + 12, lengths[index])
	}
}

fn sfnt_storage_test_collection() []u8 {
	mut bytes := []u8{len: 4096}
	write_sfnt_u32(mut bytes, 0, 0x74746366)
	write_sfnt_u32(mut bytes, 4, 0x00010000)
	write_sfnt_u32(mut bytes, 8, 2)
	write_sfnt_u32(mut bytes, 12, 64)
	write_sfnt_u32(mut bytes, 16, 256)
	sfnt_storage_test_directory(mut bytes, 64, ['TEST', 'kern', 'DATA', 'DUPE'], [u32(512), 600, 700, 700], [u32(5), 4, 7, 7])
	sfnt_storage_test_directory(mut bytes, 256, ['TEST', 'kern'], [u32(900), 960], [u32(9), 4])
	for index in 0 .. 12 {
		bytes[512 + index] = u8(index + 1)
		bytes[700 + index] = u8(index + 21)
		bytes[900 + index] = u8(index + 41)
	}
	bytes[601] = 1
	return bytes
}

fn test_sfnt_streaming_selects_and_relocates_all_tables_and_shares_identical_regions() {
	bytes := sfnt_storage_test_collection()
	path := sfnt_storage_test_path()
	os.write_file_array(path, bytes)!
	defer { os.rm(path) or {} }
	first := read_outline_face_bytes(path, 0) or { panic('missing first selected face') }
	assert first.len == 12 + 4 * 16 + 8 + 4 + 8
	assert font_u32_at(first, 0)? == 0x00010000
	assert first[..12] == bytes[64..76]
	for index, source_offset in [512, 600, 700, 700] {
		record := 12 + index * 16
		length := int(font_u32_at(first, record + 12)?)
		destination := int(font_u32_at(first, record + 8)?)
		assert first[destination..destination + length] == bytes[source_offset..source_offset + length]
		assert font_u32_at(first, record + 4)? == 0x12345678 + u32(index)
	}
	assert first[28..32].bytestr() == 'Kern'
	assert font_u32_at(first, 12 + 2 * 16 + 8)? == font_u32_at(first, 12 + 3 * 16 + 8)?
	second := read_outline_face_bytes(path, 1) or { panic('missing second selected face') }
	assert second.len == 12 + 2 * 16 + 12 + 4
	assert second[28..32].bytestr() == 'kern'
	assert first != second
}

fn test_sfnt_streaming_preserves_standalone_kern_and_supplies_only_missing_final_padding() {
	mut bytes := []u8{len: 79}
	sfnt_storage_test_directory(mut bytes, 0, ['TEST', 'kern'], [u32(64), 75], [u32(5), 4])
	bytes[76] = 1
	path := sfnt_storage_test_path()
	os.write_file_array(path, bytes)!
	defer { os.rm(path) or {} }
	standalone := read_outline_face_bytes(path, 0) or { panic('missing standalone font') }
	assert standalone.len == 12 + 2 * 16 + 8 + 4
	assert standalone[28..32].bytestr() == 'kern'
	assert read_outline_face_bytes(path, 1) == none
	// A final table may omit up to three pad bytes on disk. Its declared
	// payload remains exact and its private reader padding must be zero.
	mut unpadded := []u8{len: 65}
	sfnt_storage_test_directory(mut unpadded, 0, ['TEST'], [u32(64)], [u32(1)])
	unpadded[64] = 99
	os.write_file_array(path, unpadded)!
	padded := read_outline_face_bytes(path, 0) or { panic('missing final unpadded table') }
	assert padded.len == 32
	assert padded[28..32] == [u8(99), 0, 0, 0]
}

fn test_sfnt_streaming_rejects_invalid_collection_counts_indices_directories_and_ranges() {
	path := sfnt_storage_test_path()
	defer { os.rm(path) or {} }
	valid := sfnt_storage_test_collection()
	os.write_file_array(path, valid)!
	for index in [-1, 2, 0x7fffffff] { assert read_outline_face_bytes(path, index) == none }
	mut cases := [][]u8{}
	for size in [0, 4, 11, 12, 19] { cases << valid[..size].clone() }
	for edit in [[4, 0], [8, 0], [8, 0x7fffffff], [12, 0x7fffffff], [12, 4088], [12, 12], [64 + 12 + 8, 4095], [64 + 12 + 12, 0x7fffffff]] {
		mut malformed := valid.clone()
		write_sfnt_u32(mut malformed, edit[0], u32(edit[1]))
		cases << malformed
	}
	mut large_directory := valid.clone()
	large_directory[68] = 255
	large_directory[69] = 255
	cases << large_directory
	mut unknown_sfnt := valid.clone()
	write_sfnt_u32(mut unknown_sfnt, 64, 0x01020304)
	cases << unknown_sfnt
	for bytes in cases {
		os.write_file_array(path, bytes)!
		assert read_outline_face_bytes(path, 0) == none
	}
	// TTC v2 also owns the three DSIG-header words after its face offsets.
	mut truncated_v2 := valid[..20].clone()
	write_sfnt_u32(mut truncated_v2, 4, 0x00020000)
	os.write_file_array(path, truncated_v2)!
	assert read_outline_face_bytes(path, 0) == none
	mut valid_v2 := valid.clone()
	write_sfnt_u32(mut valid_v2, 4, 0x00020000)
	os.write_file_array(path, valid_v2)!
	assert read_outline_face_bytes(path, 0) != none
}

fn sfnt_storage_test_compare_all_tables(original []u8, compact []u8) {
	count := int(font_u16_at(original, 4) or { panic('missing original directory') })
	assert (font_u16_at(compact, 4) or { panic('missing compact count') }) == count
	assert original[..12] == compact[..12]
	for index in 0 .. count {
		record := 12 + index * 16
		assert original[record..record + 8] == compact[record..record + 8]
		length := int((font_u32_at(original, record + 12) or { panic('missing table metadata') }))
		assert int((font_u32_at(compact, record + 12) or { panic('missing table metadata') })) == length
		old_offset := int((font_u32_at(original, record + 8) or { panic('missing table metadata') }))
		new_offset := int((font_u32_at(compact, record + 8) or { panic('missing table metadata') }))
		assert original[old_offset..old_offset + length] == compact[new_offset..new_offset + length]
	}
}

fn sfnt_storage_test_init_face(bytes []u8) &ttf.TTF_File {
	mut normalized := bytes.clone()
	normalize_table_checksums(mut normalized)
	mut face := &ttf.TTF_File{buf: normalized, panose_array: []u8{len: 12}, width_scale: 1}
	face.init()
	return face
}

fn test_sfnt_streaming_real_collection_tables_metrics_and_outlines_match_the_legacy_adapter() {
	mut paths := []string{}
	mut indices := []int{}
	serenity := bundled_font_path('SerenitySans-Regular.ttf') or { panic('missing test font') }
	paths << serenity
	indices << 0
	$if macos {
		paths << ['/System/Library/Fonts/AppleSDGothicNeo.ttc', '/System/Library/Fonts/AppleSDGothicNeo.ttc', '/System/Library/Fonts/HelveticaNeue.ttc', '/System/Library/Fonts/Supplemental/Songti.ttc', '/System/Library/Fonts/Supplemental/STIXGeneral.otf']
		indices << [0, 17, 1, 0, 0]
	}
	for row, path in paths {
		// Previous fixture faces may leave address-keyed glyph metrics behind.
		// Exercise their ownership across collection before decoding another face.
		gc_collect()
		raw := os.read_bytes(path)!
		legacy := sfnt_storage_test_legacy_outline_bytes_for_face(raw, indices[row]) or { panic('legacy adapter rejected real face') }
		compact := read_outline_face_bytes(path, indices[row]) or { panic('stream reader rejected real face') }
		sfnt_storage_test_compare_all_tables(legacy, compact)
		assert compact.len <= raw.len
		if path.contains('AppleSDGothicNeo') || path.contains('Songti') { assert compact.len < raw.len / 10 }
		mut old_face := sfnt_storage_test_init_face(legacy)
		mut new_face := sfnt_storage_test_init_face(compact)
		assert old_face.units_per_em == new_face.units_per_em
		assert old_face.ascent == new_face.ascent
		assert old_face.descent == new_face.descent
		assert old_face.length == new_face.length
		old_font := &Font{family: 'LegacySfntFixture', point_size: 13.5, decoded_face_: old_face}
		new_font := &Font{family: 'CompactSfntFixture', point_size: 13.5, decoded_face_: new_face}
		assert old_font.pixel_metrics_uncached() == new_font.pixel_metrics_uncached()
		for character in [u32(`A`), u32(`x`), u32(`0`), u32(0x03bb), u32(0xac00), u32(0x65e5)] {
			old_glyph := old_face.map_code(int(character))
			new_glyph := new_face.map_code(int(character))
			assert old_glyph == new_glyph
			old_advance, old_bearing := old_face.get_horizontal_metrics(old_glyph)
			new_advance, new_bearing := new_face.get_horizontal_metrics(new_glyph)
			assert old_advance == new_advance
			assert old_bearing == new_bearing
			assert old_font.glyph_bounds(int(old_glyph)) == new_font.glyph_bounds(int(new_glyph))
			assert old_font.glyph_outline(int(old_glyph)) == new_font.glyph_outline(int(new_glyph))
		}
	}
}

fn test_sfnt_streaming_rejects_storage_sum_overflow_without_reading_sparse_table_bodies() {
	path := sfnt_storage_test_path()
	defer { os.rm(path) or {} }
	mut header := []u8{len: 64}
	sfnt_storage_test_directory(mut header, 0, ['TEST', 'DATA'], [u32(64), 128], [u32(1_090_000_000), 1_090_000_000])
	os.write_file_array(path, header)!
	os.truncate(path, 1_100_000_000)!
	assert read_outline_face_bytes(path, 0) == none
	os.truncate(path, u64(0x80000000))!
	assert read_outline_face_bytes(path, 0) == none
}

fn test_sfnt_streaming_allocates_selected_tables_without_a_whole_collection_temporary() {
	$if macos {
		path := '/System/Library/Fonts/AppleSDGothicNeo.ttc'
		mut before := usize(0)
		$if gcboehm ? { before = C.GC_get_total_bytes() }
		compact := read_outline_face_bytes(path, 0) or { panic('missing compact collection face') }
		$if gcboehm ? {
			allocated := C.GC_get_total_bytes() - before
			assert allocated < usize(compact.len) + usize(2) * 1024 * 1024
		}
		assert compact.len < 4 * 1024 * 1024
		assert compact.len < int(os.file_size(path) / 10)
		gc_collect()
		assert font_u16_at(compact, 4)? > 0
	}
}

fn test_sfnt_streaming_preserves_the_complete_selected_emoji_bitmap_table() {
	$if macos {
		path := '/System/Library/Fonts/Apple Color Emoji.ttc'
		raw := os.read_bytes(path)!
		legacy := sfnt_storage_test_legacy_outline_bytes_for_face(raw, 0) or { panic('missing legacy emoji face') }
		compact := read_outline_face_bytes(path, 0) or { panic('missing compact emoji face') }
		sfnt_storage_test_compare_all_tables(legacy, compact)
		assert font_table_offset(compact, 'sbix') != none
		// Most of this collection is the selected face's bitmap payload; it
		// must remain present even though collection compaction saves little.
		assert compact.len > 180 * 1024 * 1024
		assert compact.len <= raw.len
	}
}

// Exact pre-compaction adapter retained only as a test oracle.
// x.ttf reads a standalone sfnt directory at byte zero. A TrueType collection
// keeps each face's directory elsewhere while its table offsets remain absolute,
// so copying only the selected directory to byte zero makes that same reader
// consume the requested collection face without touching shared table data.
fn sfnt_storage_test_legacy_outline_bytes_for_face(bytes []u8, face_index int) ?[]u8 {
	if bytes.len < 4 || bytes[..4].bytestr() != 'ttcf' {
		if face_index != 0 {
			return none
		}
		return bytes
	}
	face_count := int(font_u32_at(bytes, 8)?)
	if face_index < 0 || face_index >= face_count {
		return none
	}
	directory_offset := int(font_u32_at(bytes, 12 + face_index * 4)?)
	table_count := int(font_u16_at(bytes, directory_offset + 4)?)
	directory_length := 12 + table_count * 16
	if directory_offset < 0 || directory_offset + directory_length > bytes.len {
		return none
	}
	mut adapted := bytes.clone()
	copy(mut adapted[..directory_length], bytes[directory_offset..directory_offset + directory_length])
	// Apple's collection faces carry a version-1 `kern` table. x.ttf only
	// understands the OpenType version-0 form and asserts while reading any
	// other version. HarfBuzz remains the source of truth for shaped kerning,
	// so hide this one unsupported table from the outline/metrics reader.
	for index in 0 .. table_count {
		record := 12 + index * 16
		if adapted[record..record + 4].bytestr() != 'kern' {
			continue
		}
		table_offset := int(font_u32_at(adapted, record + 8)?)
		if font_u16_at(adapted, table_offset)? != 0 {
			adapted[record] = `K`
		}
	}
	return adapted
}

