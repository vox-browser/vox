module platform

import os
import time
import x.ttf

fn coverage_test_path() string {
	return os.join_path(os.temp_dir(), 'vox-coverage-${os.getpid()}-${time.sys_mono_now()}.ttf')
}

fn coverage_test_sfnt(glyph u8) []u8 {
	mut bytes := []u8{len: 28 + 12 + 262}
	write_sfnt_u32(mut bytes, 0, 0x00010000)
	bytes[5] = 1
	copy(mut bytes[12..16], 'cmap'.bytes())
	write_sfnt_u32(mut bytes, 20, 28)
	write_sfnt_u32(mut bytes, 24, u32(bytes.len - 28))
	bytes[31] = 1
	bytes[33] = 3
	bytes[35] = 1
	write_sfnt_u32(mut bytes, 36, 12)
	bytes[42] = 1
	bytes[43] = 6
	bytes[46 + 65] = glyph
	return bytes
}

fn test_source_font_coverage_matches_decoded_cmap_without_loading_outlines() {
	source := bundled_font_path('SerenitySans-Regular.ttf') or { panic('missing test font') }
	path := coverage_test_path()
	os.cp(source, path)!
	defer { os.rm(path) or {} }
	font := &Font{ family: 'LazyCoverageFixture', point_size: 16, source_path: path }
	assert font.contains_glyph(u32(`A`))
	assert !font.contains_glyph(0x10000)
	assert font.decoded_face_ == unsafe { nil }
	assert !platform_font_face_attempted[font.resolved_face_cache_key_]
	bytes := os.read_bytes(path)!
	cmap := font_source_cmap_table(bytes, 0) or { panic('missing source cmap') }
	decoded := read_outline_face_bytes(path, 0) or { panic('missing decoded cmap') }
	for code_point in 0 .. 65536 {
		assert font_cmap_table_glyph(cmap, u32(code_point)) == font_cmap_glyph(decoded,
			u32(code_point)), '${code_point}'
	}
	face := font_face(font) or { panic('outline decode must remain available') }
	assert voidptr(font.decoded_face_) == voidptr(face)
	assert face.units_per_em > 0
}

fn test_source_cmap_keeps_windows_selection_last_map_and_range_offset_semantics() {
	mut bytes := coverage_test_sfnt(7)
	cmap := font_source_cmap_table(bytes, 0) or { panic('missing fixture cmap') }
	assert font_cmap_table_glyph(cmap, 65) == 7
	bytes[35] = 2
	assert font_cmap_table_glyph(cmap, 65) == 0
	bytes[35] = 1
	mut duplicated := []u8{len: 28 + 20 + 262 * 2}
	copy(mut duplicated[..28], bytes[..28])
	write_sfnt_u32(mut duplicated, 24, u32(duplicated.len - 28))
	duplicated[31] = 2
	for index in 0 .. 2 {
		record := 32 + index * 8
		duplicated[record + 1] = 3
		duplicated[record + 3] = u8(index)
		start := 48 + index * 262
		write_sfnt_u32(mut duplicated, record + 4, u32(start - 28))
		duplicated[start + 2] = 1
		duplicated[start + 3] = 6
		duplicated[start + 6 + 65] = if index == 0 { u8(5) } else { u8(0) }
	}
	last := font_source_cmap_table(duplicated, 0) or { panic('missing second cmap') }
	assert font_cmap_table_glyph(last, 65) == 0
	mut format4 := []u8{len: 66}
	copy(mut format4[..40], bytes[..40])
	write_sfnt_u32(mut format4, 24, 38)
	format4[41] = 4
	format4[43] = 26
	format4[47] = 2
	format4[55] = 65
	format4[59] = 65
	format4[61] = 1
	format4[63] = 2
	format4[65] = 9
	ranges := font_source_cmap_table(format4, 0) or { panic('missing format4 cmap') }
	assert font_cmap_table_glyph(ranges, 65) == 9
	assert font_cmap_table_glyph(ranges, 0x10000) == 0
}

fn test_source_cmap_selects_ttc_faces_and_rejects_invalid_containers() {
	first := coverage_test_sfnt(3)
	second := coverage_test_sfnt(9)
	mut collection := []u8{len: 76 + (first.len - 28) * 2}
	write_sfnt_u32(mut collection, 0, 0x74746366)
	write_sfnt_u32(mut collection, 4, 0x00010000)
	write_sfnt_u32(mut collection, 8, 2)
	for index in 0 .. 2 {
		directory := 20 + index * 28
		table := 76 + index * (first.len - 28)
		write_sfnt_u32(mut collection, 12 + index * 4, u32(directory))
		face := if index == 0 { first } else { second }
		copy(mut collection[directory..directory + 28], face[..28])
		write_sfnt_u32(mut collection, directory + 20, u32(table))
		copy(mut collection[table..table + face.len - 28], face[28..])
	}
	left := font_source_cmap_table(collection, 0) or { panic('missing first collection face') }
	right := font_source_cmap_table(collection, 1) or { panic('missing second collection face') }
	assert font_cmap_table_glyph(left, 65) == 3
	assert font_cmap_table_glyph(right, 65) == 9
	assert font_source_cmap_table(collection, 2) == none
	assert font_source_cmap_table(first, 1) == none
	assert font_source_cmap_table(first, -1) == none
	for length in 0 .. 28 {
		assert font_source_cmap_table(first[..length], 0) == none
	}
	collection[4] = 3
	assert font_source_cmap_table(collection, 0) == none
}

fn test_source_cmap_rejects_out_of_table_reads_and_keeps_decoded_bounds_safe() {
	mut bytes := coverage_test_sfnt(7)
	write_sfnt_u32(mut bytes, 24, 12)
	assert font_source_cmap_table(bytes, 0) == none
	// The decoded reader historically permits a subtable beyond the declared
	// cmap extent. Such input must use the legacy fallback, not change coverage.
	assert font_cmap_glyph(bytes, 65) == 7
	write_sfnt_u32(mut bytes, 20, u32(bytes.len + 1))
	assert font_source_cmap_table(bytes, 0) == none
	assert font_cmap_glyph(bytes, 65) == 0
	write_sfnt_u32(mut bytes, 0, 0x774f4646)
	assert font_source_cmap_table(bytes, 0) == none
}

fn test_coverage_honors_injected_and_globally_decoded_faces() {
	injected := &ttf.TTF_File{ buf: coverage_test_sfnt(11) }
	font := &Font{
		family:        'InjectedCoverageFixture'
		source_path:   '/no/such/coverage.ttf'
		decoded_face_: injected
	}
	assert font.contains_glyph(65)
	assert !font.contains_glyph(66)
	source := bundled_font_path('SerenitySans-Regular.ttf') or { panic('missing test font') }
	path := coverage_test_path()
	os.cp(source, path)!
	defer { os.rm(path) or {} }
	loaded := &Font{ family: 'LoadedCoverageFixture', source_path: path }
	face := font_face(loaded) or { panic('failed initial decode') }
	borrower := &Font{ family: 'GlobalCoverageFixture', source_path: path }
	assert borrower.font_path()? == path
	os.rm(path)!
	assert borrower.contains_glyph(65) == (font_cmap_glyph(face.buf, 65) != 0)
	assert borrower.decoded_face_ == unsafe { nil }
}

fn test_coverage_keeps_failed_decodes_authoritative_and_falls_back_for_malformed_fonts() {
	source := bundled_font_path('SerenitySans-Regular.ttf') or { panic('missing test font') }
	path := coverage_test_path()
	os.cp(source, path)!
	defer { os.rm(path) or {} }
	font := &Font{ family: 'FailedCoverageFixture', source_path: path }
	resolved := font.font_path()?
	key := font.face_cache_key(resolved, font.face_index())
	platform_font_face_attempted[key] = true
	defer { platform_font_face_attempted.delete(key) }
	assert !font.contains_glyph(65)
	assert font.harfbuzz_face_ == unsafe { nil }
	bad_path := coverage_test_path()
	os.write_file(bad_path, 'not a font')!
	defer { os.rm(bad_path) or {} }
	bad := &Font{ family: 'MalformedCoverageFixture', source_path: bad_path }
	assert !bad.contains_glyph(65)
	assert platform_font_face_attempted[bad.resolved_face_cache_key_]
	assert bad.decoded_face_ == unsafe { nil }
}

fn test_noto_bmp_native_fallback_and_non_bmp_coverage_remain_unchanged() {
	source := bundled_font_path('NotoEmoji.ttf') or { panic('missing emoji fixture') }
	path := coverage_test_path()
	os.symlink(source, path)!
	defer { os.rm(path) or {} }
	font := &Font{ family: 'Noto Emoji', source_path: path, point_size: 16 }
	assert font.contains_glyph(0x25aa)
	assert !font.contains_glyph(0x1f600)
	assert font.decoded_face_ == unsafe { nil }
	assert !platform_font_face_attempted[font.resolved_face_cache_key_]
}

fn test_lazy_coverage_caches_survive_arena_reset_and_native_retirement() {
	source := bundled_font_path('SerenitySans-Regular.ttf') or { panic('missing test font') }
	path := coverage_test_path()
	os.cp(source, path)!
	defer { os.rm(path) or {} }
	font := &Font{ family: 'ArenaCoverageFixture', source_path: path, point_size: 16 }
	mut arena := new_arena('lazy font coverage')
	defer { arena.release() }
	entry := arena.enter()
	assert font.contains_glyph(65)
	key := font.resolved_face_cache_key_
	arena.leave(entry)
	$if prealloc {
		assert !arena.contains(voidptr(key.str))
	}
	arena.reset()
	again := arena.enter()
	junk := []u8{len: 1024 * 1024, init: 0xaa}
	arena.leave(again)
	assert junk.len > 0
	assert font.contains_glyph(65)
	assert font.resolved_face_cache_key_ == key
	release_unused_text_shaping()
	assert font.contains_glyph(65)
	assert font.decoded_face_ == unsafe { nil }
	assert font.harfbuzz_face_generation_ == harfbuzz_cache_generation
	face := font_face(font) or { panic('outline decode must remain available after retirement') }
	assert face.units_per_em > 0
}
