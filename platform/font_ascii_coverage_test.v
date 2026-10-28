module platform

import os
import time

// Written for later validation; not compiled or executed before Brave parity.
fn ascii_coverage_native_oracle(font &Font, code_point u32) bool {
	face := document_harfbuzz_face(font) or { panic('missing native face') }
	native := scaled_harfbuzz_font_with_policy(face, font.point_size, font.shaping_resolution(),
		font.variations(), font.font_rendering_policy == .chromium && system_font_matching_supported()) or { panic('missing native font') }
	mut glyph := u32(0)
	return C.hb_font_get_nominal_glyph(native, font.shaping_code_point(code_point), &glyph) != 0 && glyph != 0
}

fn test_ascii_coverage_matches_native_for_present_missing_and_unicode_characters() {
	font := &Font{family:'Arial', point_size:16, font_rendering_policy:.chromium}
	if font.system_face() == none { return }
	for _ in 0 .. 3 {
		for code_point in u32(0) .. u32(128) {
			assert font.contains_glyph(code_point) == ascii_coverage_native_oracle(font, code_point)
		}
		for code_point in [u32(0x80),0xe9,0x301,0x2010,0x2011,0x4e00,0x1f600,0x10ffff] {
			assert font.contains_glyph(code_point) == ascii_coverage_native_oracle(font, code_point)
		}
	}
	assert font.ascii_coverage_known_low_ == ~u64(0)
	assert font.ascii_coverage_known_high_ == ~u64(0)
}

fn test_ascii_coverage_keys_synthetic_capitals_after_copying_a_warm_font() {
	plain := &Font{family:'Arial', point_size:16, font_rendering_policy:.chromium}
	if plain.system_face() == none { return }
	_ = plain.contains_glyph(u32(`a`))
	caps := &Font{...plain, synthesize_ascii_caps:true}
	assert caps.contains_glyph(u32(`a`)) == ascii_coverage_native_oracle(caps, u32(`a`))
	assert caps.ascii_coverage_known_high_ & (u64(1) << (u32(`A`) & 63)) != 0
	assert plain.ascii_coverage_known_high_ & (u64(1) << (u32(`A`) & 63)) == 0
	for code_point in u32(0) .. u32(128) {
		assert caps.contains_glyph(code_point) == ascii_coverage_native_oracle(caps, code_point)
	}
}

fn test_ascii_coverage_keeps_explicit_font_legacy_cmap_semantics() {
	source := bundled_font_path('SerenitySans-Regular.ttf') or { panic('missing fixture font') }
	font := &Font{family:'ExplicitCoverage', source_path:source, point_size:16, synthesize_ascii_caps:true}
	for code_point in u32(0) .. u32(128) {
		_ = harfbuzz_font_contains_glyph(font, code_point)
		assert font.contains_glyph(code_point) == ((font_coverage_glyph(font, code_point) or { u16(0) }) != 0)
	}
	assert font.ascii_coverage_generation_ == 0
}

fn test_ascii_coverage_refreshes_after_native_cache_retirement() {
	font := &Font{family:'Arial', point_size:16, font_rendering_policy:.chromium}
	if font.system_face() == none { return }
	expected := font.contains_glyph(u32(`A`))
	old_generation := font.ascii_coverage_generation_
	release_unused_harfbuzz_fonts()
	assert harfbuzz_cache_generation != old_generation
	assert font.contains_glyph(u32(`A`)) == expected
	assert font.ascii_coverage_generation_ == harfbuzz_cache_generation
	assert font.ascii_coverage_known_low_ == 0
	assert font.ascii_coverage_known_high_ == u64(1) << (u32(`A`) & 63)
}

fn test_ascii_coverage_does_not_freeze_a_missing_explicit_source() {
	source := bundled_font_path('SerenitySans-Regular.ttf') or { panic('missing fixture font') }
	path := os.join_path(os.temp_dir(),'vox-ascii-coverage-${os.getpid()}-${time.sys_mono_now()}.ttf')
	defer { os.rm(path) or {} }
	font := &Font{family:'LateCoverage', source_path:path, point_size:16}
	_ = harfbuzz_font_contains_glyph(font, u32(`A`))
	_ = font.contains_glyph(u32(`A`))
	assert font.ascii_coverage_generation_ == 0
	os.cp(source,path)!
	assert font.contains_glyph(u32(`A`))
	assert font.ascii_coverage_generation_ == 0
}

fn test_ascii_coverage_survives_a_calling_workspace_retiring() {
	font := &Font{family:'Arial', point_size:16, font_rendering_policy:.chromium}
	if font.system_face() == none { return }
	mut arena := new_arena('ASCII coverage workspace')
	entry := arena.enter()
	expected := font.contains_glyph(u32(`A`))
	arena.leave(entry)
	arena.release()
	assert font.contains_glyph(u32(`A`)) == expected
}
