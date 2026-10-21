module platform

import os
import time

fn test_harfbuzz_face_queries_do_not_allocate_repeated_path_keys() {
	source := bundled_font_path('SerenitySans-Regular.ttf') or { panic('missing test font') }
	font := &Font{family:'StableHarfBuzzFace', point_size:16, source_path:source}
	face := document_harfbuzz_face(font) or { panic('missing HarfBuzz face') }
	assert font.harfbuzz_face_ == face
	before := thread_arena_usage().used
	for _ in 0 .. 1024 { assert document_harfbuzz_face(font)? == face }
	$if prealloc { assert thread_arena_usage().used - before < 1024 }
}

fn test_harfbuzz_face_handles_follow_a_late_explicit_source() {
	source := bundled_font_path('NotoEmoji.ttf') or { panic('missing test font') }
	path := os.join_path(os.temp_dir(), 'vox-late-harfbuzz-${os.getpid()}-${time.sys_mono_now()}.ttf')
	defer { os.rm(path) or {} }
	font := &Font{family:'LateHarfBuzzFace', point_size:16, source_path:path}
	_ = document_harfbuzz_face(font)
	assert font.harfbuzz_face_ == unsafe { nil }
	os.cp(source, path)!
	face := document_harfbuzz_face(font)?
	assert font.harfbuzz_face_ == face
	expected := &Font{family:'LateHarfBuzzFace', point_size:16, source_path:source}
	for code_point in [u32(`0`), u32(0x1f600), u32(`M`)] {
		assert harfbuzz_font_contains_glyph(font, code_point) == harfbuzz_font_contains_glyph(expected, code_point)
	}
}

fn test_cached_harfbuzz_face_remains_owned_after_a_calling_workspace_retires() {
	source := bundled_font_path('SerenitySans-Regular.ttf') or { panic('missing test font') }
	font := &Font{family:'HarfBuzzWorkspaceFace', point_size:17, source_path:source}
	mut arena := new_arena('HarfBuzz query workspace')
	entry := arena.enter()
	face := document_harfbuzz_face(font)?
	covered := harfbuzz_font_contains_glyph(font, u32(`A`))?
	arena.leave(entry)
	arena.release()
	assert document_harfbuzz_face(font)? == face
	assert harfbuzz_font_contains_glyph(font, u32(`A`))? == covered
}
